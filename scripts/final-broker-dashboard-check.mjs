import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';

const rootDir = process.cwd();
const dashboardDir = path.join(rootDir, 'web-dashboard');
const outputDir = path.join(rootDir, 'output', 'playwright');
const port = Number(process.env.BROKER_DASHBOARD_PORT || 3107);
const debugPort = Number(process.env.BROKER_DASHBOARD_DEBUG_PORT || 9322);
const suppliedUrl = process.env.BROKER_DASHBOARD_URL;
const dashboardUrl = suppliedUrl || `http://127.0.0.1:${port}/broker`;
const shouldStartServer = !suppliedUrl;

const requiredTexts = [
  'Broker Business Vault',
  'Jitu Gupta',
  'JSN Enterprise',
  'protected broker attribution workspace',
  'BRK-JSN-0001',
  'Protected Lead Command Center',
  'Scale Allocation Engine',
  'Broker Team Routing',
  'Developer Routes',
  'Selected lead',
  'Lifecycle Flow',
  'Site Visit Proof Pipeline',
  'Broker Lock Ledger',
  'Live Projects',
  'Safe Activity Output',
  'L-1042',
  'L-1088',
  'L-1120',
  'L-1177',
  'No phone, no export, no direct call link.',
];

const requiredButtons = [
  'Secure Lead',
  'Secure Call',
  'Grant 24h',
  'Extend',
  'Revoke',
  'Assign Caller',
  'Assign SM',
  'Propose Site Visit',
  'Verify Visit + Create Lock',
  'Raise Issue',
  'Attach 5 SMs',
  'Attach 5 Developers',
  'Route 50 Leads',
];

class CdpClient {
  constructor(wsUrl) {
    this.nextId = 1;
    this.pending = new Map();
    this.eventWaiters = [];
    this.events = [];
    this.ready = new Promise((resolve, reject) => {
      this.socket = new WebSocket(wsUrl);
      this.socket.addEventListener('open', resolve, { once: true });
      this.socket.addEventListener('error', (event) => {
        reject(new Error(`CDP websocket failed: ${event.message || 'unknown error'}`));
      }, { once: true });
      this.socket.addEventListener('message', (event) => this.handleMessage(event.data));
    });
  }

  handleMessage(data) {
    const message = JSON.parse(String(data));
    if (message.id && this.pending.has(message.id)) {
      const { resolve, reject, timeoutId } = this.pending.get(message.id);
      clearTimeout(timeoutId);
      this.pending.delete(message.id);
      if (message.error) {
        reject(new Error(`${message.error.message}: ${message.error.data || ''}`.trim()));
      } else {
        resolve(message.result || {});
      }
      return;
    }

    if (message.method) {
      this.events.push(message);
      for (let i = this.eventWaiters.length - 1; i >= 0; i -= 1) {
        const waiter = this.eventWaiters[i];
        const sessionMatches = !waiter.sessionId || waiter.sessionId === message.sessionId;
        if (waiter.method === message.method && sessionMatches && waiter.predicate(message)) {
          clearTimeout(waiter.timeoutId);
          this.eventWaiters.splice(i, 1);
          waiter.resolve(message);
        }
      }
    }
  }

  async send(method, params = {}, sessionId) {
    await this.ready;
    const id = this.nextId;
    this.nextId += 1;
    const payload = { id, method, params };
    if (sessionId) payload.sessionId = sessionId;

    return new Promise((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Timed out waiting for CDP method ${method}`));
      }, 30000);
      this.pending.set(id, { resolve, reject, timeoutId });
      this.socket.send(JSON.stringify(payload));
    });
  }

  waitForEvent(method, sessionId, predicate = () => true, timeoutMs = 30000) {
    return new Promise((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        this.eventWaiters = this.eventWaiters.filter((waiter) => waiter.resolve !== resolve);
        reject(new Error(`Timed out waiting for CDP event ${method}`));
      }, timeoutMs);
      this.eventWaiters.push({ method, sessionId, predicate, resolve, timeoutId });
    });
  }

  close() {
    this.socket.close();
  }
}

function commandName(base) {
  return process.platform === 'win32' ? `${base}.cmd` : base;
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function stopProcessTree(child) {
  if (!child || child.killed) return;
  if (process.platform === 'win32' && child.pid) {
    await new Promise((resolve) => {
      const killer = spawn('taskkill', ['/pid', String(child.pid), '/T', '/F'], {
        windowsHide: true,
        stdio: 'ignore',
      });
      killer.on('close', resolve);
      killer.on('error', resolve);
    });
    return;
  }
  child.kill('SIGTERM');
}

async function removeDirQuietly(dir) {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      await rm(dir, { recursive: true, force: true });
      return;
    } catch (error) {
      if (attempt === 4) return;
      await delay(300);
    }
  }
}

async function waitForHttp(url, timeoutMs) {
  const startedAt = Date.now();
  let lastError;
  while (Date.now() - startedAt < timeoutMs) {
    try {
      const response = await fetch(url, { cache: 'no-store' });
      if (response.ok) return;
      lastError = new Error(`HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await delay(500);
  }
  throw new Error(`Timed out waiting for ${url}: ${lastError?.message || 'no response'}`);
}

async function startDashboardServer() {
  const stdoutPath = path.join(outputDir, 'broker-dashboard-localhost.stdout.log');
  const stderrPath = path.join(outputDir, 'broker-dashboard-localhost.stderr.log');
  const stdoutChunks = [];
  const stderrChunks = [];
  const command = process.platform === 'win32' ? 'cmd.exe' : commandName('npm');
  const args = process.platform === 'win32'
    ? ['/d', '/s', '/c', `npm run dev -- --webpack --hostname 127.0.0.1 --port ${port}`]
    : ['run', 'dev', '--', '--webpack', '--hostname', '127.0.0.1', '--port', String(port)];
  const server = spawn(
    command,
    args,
    {
      cwd: dashboardDir,
      shell: false,
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );

  server.stdout.on('data', (chunk) => stdoutChunks.push(chunk));
  server.stderr.on('data', (chunk) => stderrChunks.push(chunk));
  await waitForHttp(dashboardUrl, 120000).catch(async (error) => {
    await writeFile(stdoutPath, Buffer.concat(stdoutChunks));
    await writeFile(stderrPath, Buffer.concat(stderrChunks));
    throw error;
  });
  await writeFile(stdoutPath, Buffer.concat(stdoutChunks));
  await writeFile(stderrPath, Buffer.concat(stderrChunks));
  return server;
}

function findBrowserPath() {
  const candidates = [
    process.env.BROWSER_PATH,
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/usr/bin/microsoft-edge',
  ].filter(Boolean);

  const browserPath = candidates.find((candidate) => existsSync(candidate));
  if (!browserPath) {
    throw new Error('No Chromium browser found. Set BROWSER_PATH to Chrome or Edge to run this check.');
  }
  return browserPath;
}

async function launchBrowser() {
  const browserPath = findBrowserPath();
  const userDataDir = await mkdtemp(path.join(outputDir, 'futuretrust-broker-dashboard-'));
  const browser = spawn(browserPath, [
    '--headless=new',
    '--disable-gpu',
    '--no-first-run',
    '--no-default-browser-check',
    `--remote-debugging-port=${debugPort}`,
    `--user-data-dir=${userDataDir}`,
    'about:blank',
  ], {
    windowsHide: true,
    stdio: 'ignore',
  });

  await waitForHttp(`http://127.0.0.1:${debugPort}/json/version`, 30000);
  const versionResponse = await fetch(`http://127.0.0.1:${debugPort}/json/version`);
  const version = await versionResponse.json();
  return { browser, userDataDir, webSocketDebuggerUrl: version.webSocketDebuggerUrl };
}

async function evaluate(client, sessionId, expression) {
  const response = await client.send('Runtime.evaluate', {
    expression,
    awaitPromise: true,
    returnByValue: true,
    userGesture: true,
  }, sessionId);

  if (response.exceptionDetails) {
    throw new Error(`Browser evaluation failed: ${response.exceptionDetails.text}`);
  }
  return response.result.value;
}

async function waitForExpression(client, sessionId, expression, timeoutMs = 30000) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    try {
      if (await evaluate(client, sessionId, expression)) return;
    } catch {
      // The app can briefly remount while Next.js finishes compiling.
    }
    await delay(250);
  }
  throw new Error(`Timed out waiting for expression: ${expression}`);
}

async function setViewport(client, sessionId, viewport) {
  await client.send('Emulation.setDeviceMetricsOverride', {
    width: viewport.width,
    height: viewport.height,
    deviceScaleFactor: 1,
    mobile: viewport.mobile,
    screenOrientation: viewport.mobile
      ? { type: 'portraitPrimary', angle: 0 }
      : { type: 'landscapePrimary', angle: 0 },
  }, sessionId);
  await client.send('Emulation.setTouchEmulationEnabled', {
    enabled: viewport.mobile,
  }, sessionId);
}

async function navigate(client, sessionId, url) {
  const loadEvent = client.waitForEvent('Page.loadEventFired', sessionId).catch(() => null);
  await client.send('Page.navigate', { url }, sessionId);
  await loadEvent;
  await waitForExpression(
    client,
    sessionId,
    "document.readyState !== 'loading' && document.body && document.body.innerText.includes('Protected Lead Command Center')",
    60000,
  );
}

async function captureScreenshot(client, sessionId, fileName) {
  const screenshot = await client.send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
  }, sessionId);
  const screenshotPath = path.join(outputDir, fileName);
  await writeFile(screenshotPath, screenshot.data, 'base64');
  return screenshotPath;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function collectPageState(client, sessionId) {
  return evaluate(client, sessionId, `(() => {
    const text = document.body.innerText;
    const normalizedText = text.replace(/\\s+/g, ' ');
    const normalizedLowerText = normalizedText.toLowerCase();
    const buttons = Array.from(document.querySelectorAll('button')).map((button) => button.innerText.trim()).filter(Boolean);
    const leadAliases = Array.from(document.querySelectorAll('[data-testid^="lead-card-"]'))
      .map((card) => card.getAttribute('data-testid').replace('lead-card-', ''));
    const rawPhoneMatches = normalizedText.match(/(?:\\+91[\\s-]?)?[6-9]\\d{9}/g) || [];
    const scrollWidth = Math.max(document.documentElement.scrollWidth, document.body.scrollWidth);
    const viewportWidth = window.innerWidth;
    return {
      title: document.title,
      url: location.href,
      textLength: text.length,
      missingTexts: ${JSON.stringify(requiredTexts)}.filter((item) => !normalizedLowerText.includes(item.toLowerCase())),
      missingButtons: ${JSON.stringify(requiredButtons)}.filter((item) => !buttons.includes(item)),
      leadAliases,
      rawPhoneMatches,
      scrollWidth,
      viewportWidth,
      hasHorizontalOverflow: scrollWidth > viewportWidth + 2,
    };
  })()`);
}

async function runStaticAssertions(client, sessionId, viewportName) {
  const state = await collectPageState(client, sessionId);
  assert(state.title.includes('FutureTrust Broker Dashboard'), `${viewportName}: browser title is not FutureTrust-specific`);
  assert(state.textLength > 800, `${viewportName}: dashboard rendered too little text`);
  assert(state.missingTexts.length === 0, `${viewportName}: missing dashboard text: ${state.missingTexts.join(', ')}`);
  assert(state.missingButtons.length === 0, `${viewportName}: missing action buttons: ${state.missingButtons.join(', ')}`);
  assert(state.leadAliases.length >= 4, `${viewportName}: expected at least four broker lead cards`);
  assert(state.rawPhoneMatches.length === 0, `${viewportName}: raw phone number exposed: ${state.rawPhoneMatches.join(', ')}`);
  assert(!state.hasHorizontalOverflow, `${viewportName}: horizontal overflow ${state.scrollWidth}px > ${state.viewportWidth}px`);
  return state;
}

async function runInteractions(client, sessionId) {
  await evaluate(client, sessionId, `(() => {
    const button = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.trim() === 'Secure Lead');
    button.click();
  })()`);
  await waitForExpression(client, sessionId, "document.body.innerText.includes('Secure Lead Intake')");

  const nextWeek = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().slice(0, 16);
  await evaluate(client, sessionId, `(() => {
    const form = document.querySelector('form');
    const setValue = (selector, value) => {
      const element = form.querySelector(selector);
      const prototype = element instanceof HTMLTextAreaElement
        ? HTMLTextAreaElement.prototype
        : element instanceof HTMLSelectElement
          ? HTMLSelectElement.prototype
          : HTMLInputElement.prototype;
      Object.getOwnPropertyDescriptor(prototype, 'value').set.call(element, value);
      element.dispatchEvent(new Event('input', { bubbles: true }));
      element.dispatchEvent(new Event('change', { bubbles: true }));
    };
    const selects = Array.from(form.querySelectorAll('select'));
    setValue('input[placeholder="L-1201"]', 'L-1301');
    setValue('input[placeholder="Encrypted after submit"]', '9876543210');
    setValue('input[placeholder="Mira Road"]', 'Borivali');
    setValue('input[placeholder="Mumbai"]', 'Mumbai');
    setValue('input[placeholder="8000000"]', '7000000');
    setValue('input[placeholder="10000000"]', '9500000');
    Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set.call(selects[0], 'Lodha Amara');
    selects[0].dispatchEvent(new Event('change', { bubbles: true }));
    Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set.call(selects[1], 'End User');
    selects[1].dispatchEvent(new Event('change', { bubbles: true }));
    const submit = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.includes('Encrypt and Secure'));
    submit.click();
  })()`);
  await waitForExpression(client, sessionId, "document.body.innerText.includes('L-1301 secured in broker vault')");
  const intakeScreenshot = await captureScreenshot(client, sessionId, 'broker-dashboard-intake-mobile.png');

  await waitForExpression(client, sessionId, "Boolean(document.querySelector('[data-testid=\"lead-card-L-1088\"]'))");
  await evaluate(client, sessionId, "document.querySelector('[data-testid=\"lead-card-L-1088\"]').click()");
  await waitForExpression(client, sessionId, "document.body.innerText.toLowerCase().includes('selected lead') && document.body.innerText.includes('L-1088')");
  await evaluate(client, sessionId, `(() => {
    const button = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.trim() === 'Secure Call');
    button.click();
  })()`);
  await waitForExpression(client, sessionId, "document.body.innerText.includes('Secure call blocked for L-1088')");

  await evaluate(client, sessionId, `(() => {
    const button = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.trim() === 'Grant 24h');
    button.click();
  })()`);
  await waitForExpression(client, sessionId, "document.body.innerText.includes('Call access granted for L-1088')");

  await evaluate(client, sessionId, `(() => {
    const button = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.trim() === 'Secure Call');
    button.click();
  })()`);
  await waitForExpression(client, sessionId, "document.body.innerText.includes('Secure call queued for L-1088')");

  await evaluate(client, sessionId, `(() => {
    const inputs = Array.from(document.querySelectorAll('input[type="datetime-local"]'));
    inputs.forEach((input) => {
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(input, '${nextWeek}');
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
    });
    const notes = document.querySelector('textarea');
    Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(notes, 'Final localhost verification');
    notes.dispatchEvent(new Event('input', { bubbles: true }));
    const button = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.includes('Propose Site Visit'));
    button.click();
  })()`);
  await waitForExpression(client, sessionId, "document.body.innerText.includes('Site visit proposed for L-1088')");
  const proposalScreenshot = await captureScreenshot(client, sessionId, 'broker-dashboard-proposal-mobile.png');

  await evaluate(client, sessionId, `(() => {
    const button = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.includes('Verify Visit + Create Lock'));
    button.click();
  })()`);
  await waitForExpression(client, sessionId, "document.body.innerText.includes('Broker lock active for L-1088')");
  const lockScreenshot = await captureScreenshot(client, sessionId, 'broker-dashboard-lock-mobile.png');

  await evaluate(client, sessionId, `(() => {
    const button = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.trim() === 'Attach 5 SMs');
    button.click();
  })()`);
  await waitForExpression(client, sessionId, "document.body.innerText.includes('sourcing managers attached')");

  await evaluate(client, sessionId, `(() => {
    const button = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.trim() === 'Attach 5 Developers');
    button.click();
  })()`);
  await waitForExpression(client, sessionId, "document.body.innerText.includes('developer routes attached')");

  await evaluate(client, sessionId, `(() => {
    const button = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.trim() === 'Route 50 Leads');
    button.click();
  })()`);
  await waitForExpression(client, sessionId, "document.body.innerText.includes('leads routed')");
  const scaleScreenshot = await captureScreenshot(client, sessionId, 'broker-dashboard-scale-mobile.png');

  return { intakeScreenshot, proposalScreenshot, lockScreenshot, scaleScreenshot };
}

async function main() {
  await mkdir(outputDir, { recursive: true });

  let server;
  let browser;
  let userDataDir;
  let client;
  const consoleErrors = [];

  try {
    if (shouldStartServer) {
      server = await startDashboardServer();
    } else {
      await waitForHttp(dashboardUrl, 30000);
    }

    const browserLaunch = await launchBrowser();
    browser = browserLaunch.browser;
    userDataDir = browserLaunch.userDataDir;
    client = new CdpClient(browserLaunch.webSocketDebuggerUrl);
    await client.ready;

    const { targetId } = await client.send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await client.send('Target.attachToTarget', { targetId, flatten: true });

    await client.send('Page.enable', {}, sessionId);
    await client.send('Runtime.enable', {}, sessionId);
    await client.send('Log.enable', {}, sessionId);

    const originalHandleMessage = client.handleMessage.bind(client);
    client.handleMessage = (data) => {
      originalHandleMessage(data);
      const message = JSON.parse(String(data));
      if (message.sessionId !== sessionId) return;
      if (message.method === 'Runtime.exceptionThrown') {
        consoleErrors.push(message.params.exceptionDetails.text || 'Runtime exception');
      }
      if (message.method === 'Runtime.consoleAPICalled' && message.params.type === 'error') {
        consoleErrors.push(message.params.args.map((arg) => arg.value || arg.description || '').join(' '));
      }
    };

    const results = [];
    const viewports = [
      { name: 'mobile', width: 390, height: 844, mobile: true },
      { name: 'desktop', width: 1366, height: 900, mobile: false },
    ];

    let interactionScreenshots = {};
    for (const viewport of viewports) {
      await setViewport(client, sessionId, viewport);
      await navigate(client, sessionId, dashboardUrl);
      const state = await runStaticAssertions(client, sessionId, viewport.name);
      const screenshot = await captureScreenshot(client, sessionId, `broker-dashboard-${viewport.name}.png`);
      results.push({ viewport: viewport.name, screenshot, state });
      if (viewport.name === 'mobile') {
        interactionScreenshots = await runInteractions(client, sessionId);
      }
    }

    assert(consoleErrors.length === 0, `browser console/runtime errors: ${consoleErrors.join(' | ')}`);

    const report = {
      status: 'PASS',
      url: dashboardUrl,
      startedLocalServer: shouldStartServer,
      screenshots: results.map((result) => result.screenshot).concat(Object.values(interactionScreenshots)),
      checks: {
        requiredTexts: requiredTexts.length,
        requiredButtons: requiredButtons.length,
        viewportCount: results.length,
        rawPhoneExposure: false,
        horizontalOverflow: false,
        actionsBottomSheet: true,
        siteVisitProposal: true,
        scaleAssignment: true,
      },
      results,
    };
    const reportPath = path.join(outputDir, 'broker-dashboard-final-check.json');
    await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
    console.log(`FINAL_BROKER_DASHBOARD_CHECK_PASS ${reportPath}`);
  } finally {
    if (client) client.close();
    if (browser) await stopProcessTree(browser);
    if (server) await stopProcessTree(server);
    if (userDataDir) {
      await removeDirQuietly(userDataDir);
    }
  }
}

main().catch(async (error) => {
  const failurePath = path.join(outputDir, 'broker-dashboard-final-check.failure.txt');
  await mkdir(outputDir, { recursive: true });
  await writeFile(failurePath, `${error.stack || error.message}\n`);
  try {
    const stdoutPath = path.join(outputDir, 'broker-dashboard-localhost.stdout.log');
    const stderrPath = path.join(outputDir, 'broker-dashboard-localhost.stderr.log');
    const stdout = existsSync(stdoutPath) ? await readFile(stdoutPath, 'utf8') : '';
    const stderr = existsSync(stderrPath) ? await readFile(stderrPath, 'utf8') : '';
    if (stdout || stderr) {
      await writeFile(failurePath, `${error.stack || error.message}\n\n--- stdout ---\n${stdout}\n--- stderr ---\n${stderr}\n`);
    }
  } catch {
    // Keep the original failure if log collection fails.
  }
  console.error(`FINAL_BROKER_DASHBOARD_CHECK_FAIL ${failurePath}`);
  console.error(error);
  process.exitCode = 1;
});

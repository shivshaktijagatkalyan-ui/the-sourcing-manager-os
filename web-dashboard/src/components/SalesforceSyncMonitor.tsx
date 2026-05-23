'use client';

import React, { useState, useMemo } from 'react';
import {
  Activity,
  ShieldCheck,
  Zap,
  PhoneCall,
  Lock,
  Database,
  ArrowRightLeft,
  ChevronRight,
  ShieldAlert,
  RotateCw,
  RefreshCw,
  Search,
  Filter,
  Eye,
  EyeOff,
  Code,
  AlertTriangle,
  Play,
  FileCode2,
  X
} from 'lucide-react';
import styles from './SalesforceSyncMonitor.module.css';

interface SyncMapping {
  id: string;
  alias: string;
  sfId: string;
  type: 'outbound_sync' | 'inbound_webhook';
  stage: 'Intake' | 'Assigned' | 'Visit Verified' | 'Booking Locked';
  status: 'SUCCESS' | 'FAILED' | 'SYNCING';
  lastSynced: string;
  errorMessage?: string;
}

interface AuditLog {
  id: string;
  timestamp: string;
  event: 'HMAC_VERIFY_SUCCESS' | 'SECURE_RPC_ENCRYPT' | 'DECRYPT_IN_MEMORY' | 'FORGED_SIGNATURE_REJECTED' | 'TOKEN_CACHE_HIT' | 'JWT_OAUTH_SUCCESS';
  actor: string;
  details: string;
  severity: 'INFO' | 'SECURE' | 'WARNING';
}

const initialMappings: SyncMapping[] = [
  {
    id: 'm-1',
    alias: 'Lead-801-Alpha',
    sfId: '00Q8a000003yG1EAAU',
    type: 'outbound_sync',
    stage: 'Visit Verified',
    status: 'SUCCESS',
    lastSynced: '12 sec ago'
  },
  {
    id: 'm-2',
    alias: 'Lead-312-Beta',
    sfId: '00Q8a000004xJ9MAAU',
    type: 'inbound_webhook',
    stage: 'Assigned',
    status: 'SUCCESS',
    lastSynced: '5 min ago'
  },
  {
    id: 'm-3',
    alias: 'Lead-909-Gamma',
    sfId: '00Q8a00005zR2EAAU',
    type: 'outbound_sync',
    stage: 'Booking Locked',
    status: 'SUCCESS',
    lastSynced: '1 min ago'
  },
  {
    id: 'm-4',
    alias: 'Lead-414-Delta',
    sfId: '',
    type: 'outbound_sync',
    stage: 'Intake',
    status: 'FAILED',
    lastSynced: '2 hours ago',
    errorMessage: 'Sync Blocked: Active Dynamic Data Loan required for Lead-414.'
  }
];

const initialLogs: AuditLog[] = [
  {
    id: 'l-1',
    timestamp: '13:52:14',
    event: 'JWT_OAUTH_SUCCESS',
    actor: 'salesforce-sync-processor',
    details: 'OAuth 2.0 JWT Bearer flow authenticated successfully. Token cached for 300s.',
    severity: 'INFO'
  },
  {
    id: 'l-2',
    timestamp: '13:52:15',
    event: 'TOKEN_CACHE_HIT',
    actor: 'salesforce-sync-processor',
    details: 'Cached OAuth Access Token utilized for Lead-909 outbound sync.',
    severity: 'INFO'
  },
  {
    id: 'l-3',
    timestamp: '13:52:16',
    event: 'DECRYPT_IN_MEMORY',
    actor: 'initiate-call',
    details: 'Decrypted contact ciphertext in memory for transient voice assistant patch. References flushed.',
    severity: 'SECURE'
  },
  {
    id: 'l-4',
    timestamp: '13:48:02',
    event: 'HMAC_VERIFY_SUCCESS',
    actor: 'salesforce-webhook',
    details: 'X-Salesforce-Signature HMAC SHA256 matches vault credential. Ingestion authorized.',
    severity: 'SECURE'
  },
  {
    id: 'l-5',
    timestamp: '13:48:03',
    event: 'SECURE_RPC_ENCRYPT',
    actor: 'salesforce-webhook',
    details: 'Lead client phone encrypted with AES256-CBC using service-role-only pgcrypto keys.',
    severity: 'SECURE'
  },
  {
    id: 'l-6',
    timestamp: '13:20:11',
    event: 'FORGED_SIGNATURE_REJECTED',
    actor: 'salesforce-webhook',
    details: 'ATTACK BLOCKED: Signature verification failed on webhook post. Returned 401 Unauthorized.',
    severity: 'WARNING'
  }
];

export default function SalesforceSyncMonitor() {
  const [mappings, setMappings] = useState<SyncMapping[]>(initialMappings);
  const [logs, setLogs] = useState<AuditLog[]>(initialLogs);
  const [searchQuery, setSearchQuery] = useState('');
  const [logFilter, setLogFilter] = useState<string>('ALL');
  const [selectedMapping, setSelectedMapping] = useState<SyncMapping | null>(null);
  const [activeTab, setActiveTab] = useState<'monitor' | 'docs'>('monitor');
  const [toastMessage, setToastMessage] = useState<string | null>(
    'System operational. HMAC verification engine initialized and ready.'
  );

  // Statistics
  const successCount = useMemo(() => mappings.filter((m) => m.status === 'SUCCESS').length, [mappings]);
  const failedCount = useMemo(() => mappings.filter((m) => m.status === 'FAILED').length, [mappings]);
  const totalCount = mappings.length;

  const triggerToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => {
      setToastMessage((prev) => (prev === msg ? null : prev));
    }, 4500);
  };

  // Webhook Simulation (Happy Path)
  const handleSimulateWebhook = () => {
    const newLeadIndex = Math.floor(Math.random() * 1000) + 500;
    const newAlias = `Lead-${newLeadIndex}-Omega`;
    const mockSfId = `00Q8a00000${Math.random().toString(36).substring(2, 10).toUpperCase()}AAU`;
    
    // 1. Add Log: HMAC verify success
    const timeStr = new Date().toLocaleTimeString('en-US', { hour12: false });
    const log1: AuditLog = {
      id: `l-sim-${Date.now()}-1`,
      timestamp: timeStr,
      event: 'HMAC_VERIFY_SUCCESS',
      actor: 'salesforce-webhook',
      details: `Inbound webhook signature verified for ${newAlias}. Payload authenticity guaranteed.`,
      severity: 'SECURE'
    };

    // 2. Add Log: SECURE RPC ENCRYPT
    const log2: AuditLog = {
      id: `l-sim-${Date.now()}-2`,
      timestamp: timeStr,
      event: 'SECURE_RPC_ENCRYPT',
      actor: 'salesforce-webhook',
      details: `Decrypted phone number from request, encrypted with AES-256 and salt, committed to secure tables.`,
      severity: 'SECURE'
    };

    // 3. Add to Mapping Table
    const newMapping: SyncMapping = {
      id: `m-${Date.now()}`,
      alias: newAlias,
      sfId: mockSfId,
      type: 'inbound_webhook',
      stage: 'Intake',
      status: 'SUCCESS',
      lastSynced: 'Just now'
    };

    setLogs((prev) => [log1, log2, ...prev]);
    setMappings((prev) => [newMapping, ...prev]);
    triggerToast(`Simulation: Ingested webhook for ${newAlias}. Phone number encrypted, SObject mapped.`);
  };

  // Malicious Webhook Simulation (Attack Path)
  const handleSimulateAttack = () => {
    const timeStr = new Date().toLocaleTimeString('en-US', { hour12: false });
    const attackLog: AuditLog = {
      id: `l-sim-${Date.now()}`,
      timestamp: timeStr,
      event: 'FORGED_SIGNATURE_REJECTED',
      actor: 'salesforce-webhook',
      details: 'FAIL-CLOSED: Received unauthorized payload with spoofed signature. Rejected with 401 Unauthorized.',
      severity: 'WARNING'
    };

    setLogs((prev) => [attackLog, ...prev]);
    triggerToast('SECURITY WARNING: Forged webhook signature detected and blocked. Fail-closed RLS engaged.');
  };

  // Outbound Queue flushing
  const handleFlushQueue = () => {
    // Look for failed or pending items and resolve them
    setMappings((prev) =>
      prev.map((m) => {
        if (m.status === 'FAILED') {
          return {
            ...m,
            status: 'SUCCESS',
            sfId: `00Q8a00000${Math.random().toString(36).substring(2, 10).toUpperCase()}AAU`,
            lastSynced: 'Just now',
            errorMessage: undefined
          };
        }
        return m;
      })
    );

    const timeStr = new Date().toLocaleTimeString('en-US', { hour12: false });
    const oauthLog: AuditLog = {
      id: `l-sim-flush-${Date.now()}`,
      timestamp: timeStr,
      event: 'JWT_OAUTH_SUCCESS',
      actor: 'salesforce-sync-processor',
      details: 'Flushed outbound queue. Dynamic authorization cache active, SObjects committed.',
      severity: 'INFO'
    };

    setLogs((prev) => [oauthLog, ...prev]);
    triggerToast('Outbound Queue Flushed: Resolved failed sync mappings successfully.');
  };

  // Single Row Force Sync
  const handleForceSync = (id: string) => {
    setMappings((prev) =>
      prev.map((m) => (m.id === id ? { ...m, status: 'SYNCING' } : m))
    );

    setTimeout(() => {
      setMappings((prev) =>
        prev.map((m) => {
          if (m.id === id) {
            return {
              ...m,
              status: 'SUCCESS',
              sfId: m.sfId || `00Q8a00000${Math.random().toString(36).substring(2, 10).toUpperCase()}AAU`,
              lastSynced: 'Just now',
              errorMessage: undefined
            };
          }
          return m;
        })
      );
      
      const timeStr = new Date().toLocaleTimeString('en-US', { hour12: false });
      const forceLog: AuditLog = {
        id: `l-sim-force-${Date.now()}`,
        timestamp: timeStr,
        event: 'TOKEN_CACHE_HIT',
        actor: 'salesforce-sync-processor',
        details: `Forced dynamic REST update for mapped SObject successfully. Mappings updated in 42ms.`,
        severity: 'INFO'
      };
      setLogs((prev) => [forceLog, ...prev]);
      triggerToast('Force sync completed successfully.');
    }, 1200);
  };

  // Filtered Logs
  const filteredLogs = useMemo(() => {
    return logs.filter((log) => {
      const matchSearch = `${log.event} ${log.details} ${log.actor}`.toLowerCase().includes(searchQuery.toLowerCase());
      if (logFilter === 'ALL') return matchSearch;
      if (logFilter === 'INFO') return matchSearch && log.severity === 'INFO';
      if (logFilter === 'SECURE') return matchSearch && log.severity === 'SECURE';
      if (logFilter === 'WARNING') return matchSearch && log.severity === 'WARNING';
      return matchSearch;
    });
  }, [logs, searchQuery, logFilter]);

  // PII Comparison Payload Data
  const getPiiComparison = (alias: string) => {
    return {
      sourcedLead: {
        id: "l-48a12b",
        alias: alias,
        contact_number: "+91 98765 43210",
        buyer_full_name: "Jitu Lalit Gupta",
        whatsapp_link: "https://wa.me/919876543210",
        broker_id: "brk-910a2",
        assigned_caller: "caller-8841",
        stage: "visit_verified",
        broker_lock: {
          status: "LOCKED",
          expiry: "45 days active"
        }
      },
      outboundRestPayload: {
        lead_uuid: "l-48a12b",
        lead_alias: alias,
        sourcing_manager_reference: "caller-8841",
        visit_verified_status: true,
        broker_commission_lock: true,
        lock_term_days: 45,
        restricted_buyer_identity: "DATALESS_COMPLIANT_ZERO_PII",
        caller_phone_parameters: "REMOVED_FROM_OUTBOUND_STREAM"
      }
    };
  };

  return (
    <div className={styles.container}>
      <div className={styles.ambientGlow1} />
      <div className={styles.ambientGlow2} />

      <div className={styles.wrapper}>
        {/* Dynamic global notification ribbon */}
        {toastMessage && (
          <div className="py-2 px-4 rounded-xl bg-slate-900/80 border border-amber-500/20 text-xs text-amber-300 flex items-center justify-between gap-3 shadow-lg shadow-black/40 z-50">
            <div className="flex items-center gap-2">
              <Zap className="w-4 h-4 text-amber-500 animate-pulse" />
              <span>{toastMessage}</span>
            </div>
            <button onClick={() => setToastMessage(null)} className="text-slate-500 hover:text-white">
              <X className="w-3 h-3" />
            </button>
          </div>
        )}

        {/* Header */}
        <header className={styles.header}>
          <div className={styles.brandGroup}>
            <div className={styles.logoIcon}>
              <ArrowRightLeft className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className={styles.brandTitle}>Sourcing Manager OS</h1>
                <span className={styles.badge}>Salesforce Sync Adapter</span>
              </div>
              <p className="text-xs text-slate-400">Secure Bi-Directional Synchronization & RLS Encrypted Ingestion Engine</p>
            </div>
          </div>

          <div className={styles.systemStatus}>
            <div className={styles.statusIndicator}>
              <div className={styles.pulseDot} />
              <span>HMAC VALIDATOR LIVE</span>
            </div>
            <div className="text-right">
              <div className={styles.metaText}>API VERSION: REST-v57.0</div>
              <div className={styles.metaText}>LAST SECURE SYNC: JUST NOW</div>
            </div>
          </div>
        </header>

        {/* Tabs Bar */}
        <div className="flex justify-between items-center bg-slate-900/40 p-1.5 rounded-xl border border-slate-800/60 max-w-sm">
          <button
            onClick={() => setActiveTab('monitor')}
            className={`flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded-lg text-xs font-semibold transition-all duration-300 ${
              activeTab === 'monitor'
                ? 'bg-[#10b981] text-[#0b141e] shadow-md shadow-[#10b981]/20 font-bold'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            <Activity className="w-3.5 h-3.5" /> Live Monitor
          </button>
          <button
            onClick={() => setActiveTab('docs')}
            className={`flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded-lg text-xs font-semibold transition-all duration-300 ${
              activeTab === 'docs'
                ? 'bg-[#10b981] text-[#0b141e] shadow-md shadow-[#10b981]/20 font-bold'
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            <FileCode2 className="w-3.5 h-3.5" /> Sync Spec & Architecture
          </button>
        </div>

        {activeTab === 'monitor' ? (
          <>
            {/* Stats Cards */}
            <div className={styles.statsGrid}>
              {/* Card 1: Webhook Ingestion */}
              <div className={styles.statCard}>
                <div className={styles.statHeader}>
                  <span className={styles.statTitle}>Inbound Webhook Intake</span>
                  <Database className={styles.statIcon} size={20} />
                </div>
                <div className="flex justify-between items-baseline">
                  <span className={styles.statValue}>12.4 <span className="text-xs text-slate-500">req/min</span></span>
                  <span className="text-xs text-emerald-400 font-bold bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                    100% SECURE
                  </span>
                </div>
                <div className={styles.statSubtext}>
                  <span>Avg Latency: <span className={styles.statHighlight}>42ms</span></span>
                  <span>•</span>
                  <span>Signature Blocks: <span className={styles.statHighlight}>{logs.filter(l => l.event === 'FORGED_SIGNATURE_REJECTED').length}</span></span>
                </div>
              </div>

              {/* Card 2: Outbound queue state */}
              <div className={styles.statCard}>
                <div className={styles.statHeader}>
                  <span className={styles.statTitle}>Outbound Processing Queue</span>
                  <ArrowRightLeft className={styles.statIcon} size={20} />
                </div>
                <div className="flex justify-between items-baseline">
                  <span className={styles.statValue}>
                    {successCount}/{totalCount} <span className="text-xs text-slate-500">syncs</span>
                  </span>
                  {failedCount > 0 ? (
                    <span className="text-xs text-rose-400 font-bold bg-rose-500/10 px-2 py-0.5 rounded border border-rose-500/20 animate-pulse">
                      {failedCount} BLOCKED
                    </span>
                  ) : (
                    <span className="text-xs text-emerald-400 font-bold bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                      SYNCED
                    </span>
                  )}
                </div>
                <div className={styles.statSubtext}>
                  <span>Queue State: <span className={styles.statHighlight}>IDLE (Empty)</span></span>
                  <span>•</span>
                  <span>Auto Retries: <span className={styles.statHighlight}>5 (Exp Backoff)</span></span>
                </div>
              </div>

              {/* Card 3: PII Isolation Badge */}
              <div className={styles.statCard}>
                <div className={styles.statHeader}>
                  <span className={styles.statTitle}>PII Isolation Guardrails</span>
                  <ShieldCheck className="text-emerald-400" size={20} />
                </div>
                <div>
                  <div className={styles.complianceBadge}>
                    <ShieldCheck size={14} /> DATALESS COMPLIANCE ACTIVE
                  </div>
                </div>
                <div className={styles.statSubtext}>
                  <span>Outgoing PII leakage: <span className="text-emerald-400 font-bold">0.0%</span></span>
                  <span>•</span>
                  <span>Vault Encryption: <span className={styles.statHighlight}>AES-256</span></span>
                </div>
              </div>
            </div>

            {/* Core Work Area */}
            <div className={styles.coreGrid}>
              {/* Left Column: Sync Mappings & Analytics */}
              <div className="space-y-6">
                {/* SVG Chart Panel */}
                <div className={styles.panel}>
                  <div className={styles.panelHeader}>
                    <h3 className={styles.panelTitle}>
                      <Activity className="w-5 h-5 text-[#10b981]" /> Webhook Ingestion & Sync Volume (24h)
                    </h3>
                    <div className="flex gap-4 text-[10px] font-bold text-slate-400 font-mono">
                      <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 bg-[#10b981] rounded" /> Inbound Webhooks</span>
                      <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 bg-[#3b82f6] rounded" /> Outbound Syncs</span>
                    </div>
                  </div>

                  <div className={styles.chartContainer}>
                    <svg viewBox="0 0 800 220" className={styles.svgChart}>
                      {/* Grid Lines */}
                      <line x1="0" y1="20" x2="800" y2="20" stroke="rgba(255,255,255,0.03)" strokeWidth="1" />
                      <line x1="0" y1="70" x2="800" y2="70" stroke="rgba(255,255,255,0.03)" strokeWidth="1" />
                      <line x1="0" y1="120" x2="800" y2="120" stroke="rgba(255,255,255,0.03)" strokeWidth="1" />
                      <line x1="0" y1="170" x2="800" y2="170" stroke="rgba(255,255,255,0.03)" strokeWidth="1" />
                      
                      {/* Chart Inbound Path (Emerald) */}
                      <path
                        d="M 0,170 Q 100,80 200,120 T 400,60 T 600,110 T 800,40"
                        fill="none"
                        stroke="#10b981"
                        strokeWidth="3.5"
                        strokeLinecap="round"
                        className="drop-shadow-[0_0_8px_rgba(16,185,129,0.3)]"
                      />
                      
                      {/* Chart Outbound Path (Blue) */}
                      <path
                        d="M 0,180 Q 80,110 180,140 T 350,90 T 550,130 T 800,55"
                        fill="none"
                        stroke="#3b82f6"
                        strokeWidth="2.5"
                        strokeDasharray="4 2"
                        strokeLinecap="round"
                      />

                      {/* Anchors/Dots */}
                      <circle cx="200" cy="120" r="4" fill="#10b981" />
                      <circle cx="400" cy="60" r="4" fill="#10b981" />
                      <circle cx="600" cy="110" r="4" fill="#10b981" />

                      <circle cx="180" cy="140" r="3.5" fill="#3b82f6" />
                      <circle cx="350" cy="90" r="3.5" fill="#3b82f6" />
                      <circle cx="550" cy="130" r="3.5" fill="#3b82f6" />
                      
                      {/* X Axis Labels */}
                      <text x="5" y="200" fill="#64748b" fontSize="10" fontFamily="monospace">10:00</text>
                      <text x="200" y="200" fill="#64748b" fontSize="10" fontFamily="monospace">11:00</text>
                      <text x="400" y="200" fill="#64748b" fontSize="10" fontFamily="monospace">12:00</text>
                      <text x="600" y="200" fill="#64748b" fontSize="10" fontFamily="monospace">13:00</text>
                      <text x="750" y="200" fill="#64748b" fontSize="10" fontFamily="monospace">NOW</text>
                    </svg>
                  </div>
                </div>

                {/* Mappings Panel */}
                <div className={styles.panel}>
                  <div className={styles.panelHeader}>
                    <h3 className={styles.panelTitle}>
                      <Database className="w-5 h-5 text-[#66fcf1]" /> Active Mappings & Synced SObjects
                    </h3>
                    <div className="text-xs text-slate-400 font-medium">
                      Bi-directional mappings: <span className="text-white font-bold">{totalCount} records linked</span>
                    </div>
                  </div>

                  <div className={styles.tableContainer}>
                    <table className={styles.table}>
                      <thead>
                        <tr>
                          <th className={styles.th}>Sourced Lead (Alias)</th>
                          <th className={styles.th}>Salesforce SObject ID</th>
                          <th className={styles.th}>Sync Flow</th>
                          <th className={styles.th}>Status</th>
                          <th className={styles.th}>Last Synced</th>
                          <th className={styles.th + " text-right"}>Compliance</th>
                        </tr>
                      </thead>
                      <tbody>
                        {mappings.map((m) => (
                          <tr key={m.id} className={styles.tr}>
                            <td className={styles.td}>
                              <div className={styles.aliasCell}>{m.alias}</div>
                              <div className="text-[10px] text-slate-500 uppercase font-mono font-bold mt-0.5">
                                {m.stage}
                              </div>
                            </td>
                            <td className={styles.td}>
                              {m.sfId ? (
                                <div className={styles.idCell}>{m.sfId}</div>
                              ) : (
                                <div className="text-rose-500 font-semibold italic text-[11px]">Unmapped / Failed</div>
                              )}
                              {m.errorMessage && (
                                <div className="text-[10px] text-rose-400 font-mono mt-1 max-w-[200px] leading-tight">
                                  {m.errorMessage}
                                </div>
                              )}
                            </td>
                            <td className={styles.td}>
                              <span className="text-[11px] font-mono text-slate-400 flex items-center gap-1">
                                {m.type === 'outbound_sync' ? 'Outbound ➡️' : '⬅️ Inbound'}
                              </span>
                            </td>
                            <td className={styles.td}>
                              {m.status === 'SYNCING' ? (
                                <div className="w-[100px] space-y-1">
                                  <div className="text-[10px] text-[#66fcf1] font-bold font-mono">SYNCING...</div>
                                  <div className={styles.syncingBar}>
                                    <div className={styles.syncingProgress} />
                                  </div>
                                </div>
                              ) : m.status === 'SUCCESS' ? (
                                <span className={styles.statusSuccess}>SUCCESS</span>
                              ) : (
                                <span className={styles.statusFailed}>FAILED</span>
                              )}
                            </td>
                            <td className={styles.td}>
                              <span className="text-xs text-slate-400 font-mono">{m.lastSynced}</span>
                            </td>
                            <td className={styles.td + " text-right"}>
                              <div className="flex justify-end gap-2">
                                <button
                                  onClick={() => setSelectedMapping(m)}
                                  className={styles.btnAction}
                                  title="Compare PII Sandbox"
                                >
                                  <Eye size={12} className="mr-1 inline" /> Payload
                                </button>
                                <button
                                  onClick={() => handleForceSync(m.id)}
                                  disabled={m.status === 'SYNCING'}
                                  className={styles.btnAction}
                                  title="Force Sync"
                                >
                                  <RefreshCw size={12} className="mr-1 inline" /> Sync
                                </button>
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>

              {/* Right Column: Simulation Controls & Real-Time RLS Logs */}
              <div className="space-y-6">
                {/* Operations & Simulator Control Card */}
                <div className={styles.panel}>
                  <h3 className={styles.panelTitle}>
                    <Zap className="w-5 h-5 text-amber-500" /> Webhook & Queue Sandbox
                  </h3>
                  
                  <div className={styles.controlCard}>
                    <span className={styles.controlLabel}>Inbound Webhook Intake Simulator</span>
                    <p className={styles.controlDescription}>
                      Simulate a Salesforce integration partner pushing a new lead event. Validates signature and runs cryptographic vault encryption.
                    </p>
                    <button onClick={handleSimulateWebhook} className={`${styles.btn} ${styles.btnPrimary}`}>
                      <Play size={12} /> Post Signed Lead Webhook
                    </button>
                  </div>

                  <div className={styles.controlCard}>
                    <span className={styles.controlLabel}>Cyber Security Intrusion Test</span>
                    <p className={styles.controlDescription}>
                      Inject a forged or tampered signature payload to test whether the webhook listener immediately triggers the fail-closed rejection.
                    </p>
                    <button onClick={handleSimulateAttack} className={`${styles.btn} ${styles.btnSecondary} hover:bg-rose-950/20 hover:border-rose-800`}>
                      <AlertTriangle size={12} className="text-rose-500" /> Spoof Forged Signature (Attack)
                    </button>
                  </div>

                  <div className={styles.controlCard}>
                    <span className={styles.controlLabel}>Outbound Queue Controller</span>
                    <p className={styles.controlDescription}>
                      Flush the pending background outbound tasks in `enterprise_task_queue` and resolve active mapped errors.
                    </p>
                    <button onClick={handleFlushQueue} className={`${styles.btn} ${styles.btnSecondary}`}>
                      <RefreshCw size={12} /> Flush Outbound Queue
                    </button>
                  </div>
                </div>

                {/* Audit Logs panel */}
                <div className={styles.panel}>
                  <div className="flex flex-col gap-2">
                    <h3 className={styles.panelTitle}>
                      <ShieldCheck className="w-5 h-5 text-emerald-400" /> RLS Security & Sync Audit Logs
                    </h3>
                    <p className="text-[11px] text-slate-500 leading-normal">
                      Immutable transactional logging proving cryptographically secure database compliance.
                    </p>
                  </div>

                  {/* Filter ribbon */}
                  <div className="flex flex-wrap gap-1.5 p-1 bg-slate-950/50 rounded-lg border border-slate-900">
                    {['ALL', 'INFO', 'SECURE', 'WARNING'].map((f) => (
                      <button
                        key={f}
                        onClick={() => setLogFilter(f)}
                        className={`px-3 py-1 rounded text-[10px] font-bold transition-all ${
                          logFilter === f
                            ? 'bg-[#1e293b] text-[#10b981] border border-slate-700'
                            : 'text-slate-500 hover:text-slate-300'
                        }`}
                      >
                        {f}
                      </button>
                    ))}
                  </div>

                  {/* Search filter */}
                  <div className="relative">
                    <Search className="w-3.5 h-3.5 text-slate-500 absolute left-2.5 top-1/2 -translate-y-1/2" />
                    <input
                      type="text"
                      placeholder="Filter audit logs..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="w-full pl-8 pr-3 py-1.5 bg-slate-900/60 border border-slate-800 rounded-lg text-[10px] text-slate-200 placeholder-slate-500 focus:outline-none"
                    />
                  </div>

                  {/* Log stream feed */}
                  <div className={styles.logFeed}>
                    {filteredLogs.map((log) => (
                      <div key={log.id} className={styles.logRow}>
                        <div className={styles.logMeta}>
                          {log.severity === 'WARNING' ? (
                            <ShieldAlert className={styles.logIconAlert} size={14} />
                          ) : (
                            <ShieldCheck className={log.severity === 'SECURE' ? styles.logIconSec : 'text-slate-500'} size={14} />
                          )}
                          <div className={styles.logTextGroup}>
                            <span className={styles.logTitle}>{log.event}</span>
                            <span className={styles.logTimestamp}>[{log.timestamp}] actor: {log.actor}</span>
                            <p className="text-[11px] text-slate-400 mt-1 leading-normal font-sans">{log.details}</p>
                          </div>
                        </div>
                        <span
                          className={`${styles.logBadge} ${
                            log.severity === 'SECURE'
                              ? styles.badgeSecure
                              : log.severity === 'WARNING'
                              ? styles.badgeReject
                              : styles.badgeAuth
                          }`}
                        >
                          {log.severity}
                        </span>
                      </div>
                    ))}
                    {filteredLogs.length === 0 && (
                      <div className="text-center py-8 text-slate-500 text-xs">No matching logs found.</div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          </>
        ) : (
          /* Tab 2: Documentation & Integration Spec */
          <div className={styles.panel}>
            <h3 className={styles.panelTitle}>
              <Code className="w-5 h-5 text-[#10b981]" /> Sourcing Manager OS Dataless Integration Contract
            </h3>

            <div className="space-y-4 text-slate-300 text-xs leading-relaxed max-w-4xl">
              <p>
                The Salesforce CRM synchronization adapter was designed from the ground up to prevent the leak of sensitive operational data. Below is the specification detailing our OAuth authentication flows and webhook protection schemes:
              </p>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-2">
                <div className="p-4 bg-slate-900/60 border border-slate-800 rounded-xl space-y-2">
                  <h4 className="font-bold text-white flex items-center gap-1.5">
                    <ShieldCheck className="w-4 h-4 text-emerald-400" /> OAuth 2.0 JWT Bearer Flow (RFC 7523)
                  </h4>
                  <p className="text-slate-400 text-[11px] leading-normal">
                    Secure server-to-server interaction. The Sourcing Manager OS generates a signed RS256 JWT assertion with private keys stored in the **Supabase Vault Registry**. Credentials never enter source control, and access tokens are cached locally for 300s to respect Salesforce API rate limits.
                  </p>
                </div>

                <div className="p-4 bg-slate-900/60 border border-slate-800 rounded-xl space-y-2">
                  <h4 className="font-bold text-white flex items-center gap-1.5">
                    <Lock className="w-4 h-4 text-[#10b981]" /> HMAC Webhook Signature Verification
                  </h4>
                  <p className="text-slate-400 text-[11px] leading-normal">
                    Inbound webhooks require validation against the shared webhook HMAC hex secret token. Spoofed signature payloads immediately fail-closed and are rejected with a `401 Unauthorized` block, registering high-priority security warnings in the audit logs.
                  </p>
                </div>
              </div>

              <div className="p-4 bg-slate-950/60 border border-slate-850 rounded-xl mt-4">
                <h4 className="font-bold text-white mb-2">Zero-PII Compliance Rule</h4>
                <p className="text-slate-400 leading-normal text-[11px]">
                  All outbound payloads directed to the Salesforce REST endpoint are stripped of restricted buyer parameters (plain text contact numbers, caller names, WhatsApp links, and broker secrets). Mappings are strictly maintained via random UUIDs and metered caller tokens, guaranteeing that external systems cannot compromise the database trust layer.
                </p>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Comparison Modal */}
      {selectedMapping && (
        <div className={styles.modalOverlay} onClick={() => setSelectedMapping(null)}>
          <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h3 className={styles.modalTitle}>PII Extraction Payload Audit</h3>
              <button className={styles.closeBtn} onClick={() => setSelectedMapping(null)}>
                <X className="w-5 h-5" />
              </button>
            </div>

            <p className="text-xs text-slate-400 leading-normal">
              Compare the internal sourced lead context (with sensitive client parameters) with the actual dataless REST payload transmitted to the Salesforce Connected App for **{selectedMapping.alias}**.
            </p>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <span className="text-[10px] text-rose-400 font-bold uppercase tracking-wider block">
                  ⚠️ Internal Lead Parameters (Restricted)
                </span>
                <pre className={styles.codeBlock}>
                  {JSON.stringify(getPiiComparison(selectedMapping.alias).sourcedLead, null, 2)}
                </pre>
              </div>

              <div className="space-y-1.5">
                <span className="text-[10px] text-emerald-400 font-bold uppercase tracking-wider block">
                  🛡️ Outbound Salesforce REST Payload
                </span>
                <pre className={styles.codeBlock}>
                  {JSON.stringify(getPiiComparison(selectedMapping.alias).outboundRestPayload, null, 2)}
                </pre>
              </div>
            </div>

            <div className="p-3 bg-emerald-500/10 border border-emerald-500/20 rounded-xl text-[11px] text-emerald-300 flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-emerald-400 flex-shrink-0" />
              <span>
                **PII Audit Passed**: Outgoing REST payload contains 0% restricted buyer variables, fully conforming to the Sourcing Manager OS Dataless Constitution.
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

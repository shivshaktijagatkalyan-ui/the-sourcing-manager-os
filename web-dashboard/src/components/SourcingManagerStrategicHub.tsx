'use client';

import React, { useState, useMemo, useEffect } from 'react';
import {
  Activity,
  ShieldCheck,
  Zap,
  Lock,
  Database,
  ArrowRightLeft,
  ShieldAlert,
  RotateCw,
  RefreshCw,
  Search,
  Filter,
  Eye,
  Play,
  FileCode2,
  X,
  TrendingUp,
  UserCheck,
  DollarSign
} from 'lucide-react';
import styles from './SourcingManagerStrategicHub.module.css';

interface StrategicLead {
  id: string;
  alias: string;
  sfId: string;
  stage: 'Intake' | 'Assigned' | 'Visit Verified' | 'Booking Locked';
  quality: 'Hot' | 'Warm' | 'Cold';
  area: string;
  project: string;
  status: 'SUCCESS' | 'FAILED' | 'SYNCING';
  lastSynced: string;
  errorMessage?: string;
}

interface ComplianceAuditLog {
  id: string;
  timestamp: string;
  event: 'HMAC_VERIFY_SUCCESS' | 'SECURE_RPC_ENCRYPT' | 'DECRYPT_IN_MEMORY' | 'FORGED_SIGNATURE_REJECTED' | 'TOKEN_CACHE_HIT' | 'JWT_OAUTH_SUCCESS';
  actor: string;
  details: string;
  severity: 'INFO' | 'SECURE' | 'WARNING';
}

const initialLeads: StrategicLead[] = [
  {
    id: 'ld-1',
    alias: 'Lead-801-Alpha',
    sfId: '00Q8a000003yG1EAAU',
    stage: 'Visit Verified',
    quality: 'Hot',
    area: 'Monterey Preserves',
    project: 'Emerald Horizon Estates',
    status: 'SUCCESS',
    lastSynced: '12s ago'
  },
  {
    id: 'ld-2',
    alias: 'Lead-312-Beta',
    sfId: '00Q8a000004xJ9MAAU',
    stage: 'Assigned',
    quality: 'Warm',
    area: 'Malibu Crest',
    project: 'Summit Ridge Heights',
    status: 'SUCCESS',
    lastSynced: '5m ago'
  },
  {
    id: 'ld-3',
    alias: 'Lead-909-Gamma',
    sfId: '00Q8a00005zR2EAAU',
    stage: 'Booking Locked',
    quality: 'Hot',
    area: 'Beverly Hills Inset',
    project: 'Luxe Skyline Penthouses',
    status: 'SUCCESS',
    lastSynced: '1m ago'
  },
  {
    id: 'ld-4',
    alias: 'Lead-414-Delta',
    sfId: '',
    stage: 'Intake',
    quality: 'Cold',
    area: 'Palo Alto Tech Preserves',
    project: 'Silicon Green Offices',
    status: 'FAILED',
    lastSynced: '2h ago',
    errorMessage: 'Sync Blocked: Active Dynamic Data Loan required for Lead-414.'
  }
];

const initialLogs: ComplianceAuditLog[] = [
  {
    id: 'l-1',
    timestamp: '15:20:11',
    event: 'JWT_OAUTH_SUCCESS',
    actor: 'salesforce-sync-processor',
    details: 'OAuth 2.0 JWT Bearer flow authenticated successfully. Token cached for 300s.',
    severity: 'INFO'
  },
  {
    id: 'l-2',
    timestamp: '15:20:12',
    event: 'TOKEN_CACHE_HIT',
    actor: 'salesforce-sync-processor',
    details: 'Cached OAuth Access Token utilized for Lead-909 outbound sync.',
    severity: 'INFO'
  },
  {
    id: 'l-3',
    timestamp: '15:19:44',
    event: 'DECRYPT_IN_MEMORY',
    actor: 'initiate-call',
    details: 'Decrypted contact ciphertext in memory for transient voice assistant patch. References flushed.',
    severity: 'SECURE'
  },
  {
    id: 'l-4',
    timestamp: '15:18:02',
    event: 'HMAC_VERIFY_SUCCESS',
    actor: 'salesforce-webhook',
    details: 'X-Salesforce-Signature HMAC SHA256 matches vault credential. Ingestion authorized.',
    severity: 'SECURE'
  },
  {
    id: 'l-5',
    timestamp: '15:18:03',
    event: 'SECURE_RPC_ENCRYPT',
    actor: 'salesforce-webhook',
    details: 'Lead client phone encrypted with AES256-CBC using service-role-only pgcrypto keys.',
    severity: 'SECURE'
  },
  {
    id: 'l-6',
    timestamp: '15:12:05',
    event: 'FORGED_SIGNATURE_REJECTED',
    actor: 'salesforce-webhook',
    details: 'ATTACK BLOCKED: Signature verification failed on webhook post. Returned 401 Unauthorized.',
    severity: 'WARNING'
  }
];

export default function SourcingManagerStrategicHub() {
  const [leads, setLeads] = useState<StrategicLead[]>(initialLeads);
  const [logs, setLogs] = useState<ComplianceAuditLog[]>(initialLogs);
  const [searchQuery, setSearchQuery] = useState('');
  const [logFilter, setLogFilter] = useState<string>('ALL');
  const [selectedLead, setSelectedLead] = useState<StrategicLead | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(
    'Strategic Hub loaded. Dual-channel cryptographic pipeline operational.'
  );

  const triggerToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => {
      setToastMessage((prev) => (prev === msg ? null : prev));
    }, 4500);
  };

  // Simulators
  const handleSimulateWebhook = () => {
    const newIndex = Math.floor(Math.random() * 900) + 100;
    const newAlias = `Lead-${newIndex}-Omega`;
    const mockSfId = `00Q8a00000${Math.random().toString(36).substring(2, 10).toUpperCase()}AAU`;
    const timeStr = new Date().toLocaleTimeString('en-US', { hour12: false });

    const log1: ComplianceAuditLog = {
      id: `l-sim-${Date.now()}-1`,
      timestamp: timeStr,
      event: 'HMAC_VERIFY_SUCCESS',
      actor: 'salesforce-webhook',
      details: `Inbound webhook signature verified for ${newAlias}. Payload authenticity guaranteed.`,
      severity: 'SECURE'
    };

    const log2: ComplianceAuditLog = {
      id: `l-sim-${Date.now()}-2`,
      timestamp: timeStr,
      event: 'SECURE_RPC_ENCRYPT',
      actor: 'salesforce-webhook',
      details: `Client phone encrypted with AES256-CBC and salt, committed to secure tables.`,
      severity: 'SECURE'
    };

    const newLead: StrategicLead = {
      id: `ld-${Date.now()}`,
      alias: newAlias,
      sfId: mockSfId,
      stage: 'Intake',
      quality: Math.random() > 0.5 ? 'Hot' : 'Warm',
      area: 'Emerald Preserves',
      project: 'The Horizon Estates',
      status: 'SUCCESS',
      lastSynced: 'Just now'
    };

    setLogs((prev) => [log1, log2, ...prev]);
    setLeads((prev) => [newLead, ...prev]);
    triggerToast(`Simulation: Ingested lead ${newAlias}. Decoupled, encrypted, and mapped.`);
  };

  const handleSimulateAttack = () => {
    const timeStr = new Date().toLocaleTimeString('en-US', { hour12: false });
    const attackLog: ComplianceAuditLog = {
      id: `l-sim-attack-${Date.now()}`,
      timestamp: timeStr,
      event: 'FORGED_SIGNATURE_REJECTED',
      actor: 'salesforce-webhook',
      details: 'FAIL-CLOSED: Webhook rejected due to forged HMAC validation signature. Returned 401 Block.',
      severity: 'WARNING'
    };

    setLogs((prev) => [attackLog, ...prev]);
    triggerToast('SECURITY ALARM: Forged signature blocked. Fail-closed defense protocol active.');
  };

  const handlePromoteStage = (id: string) => {
    setLeads((prev) =>
      prev.map((ld) => {
        if (ld.id === id) {
          const stages: StrategicLead['stage'][] = ['Intake', 'Assigned', 'Visit Verified', 'Booking Locked'];
          const currentIndex = stages.indexOf(ld.stage);
          const nextIndex = Math.min(currentIndex + 1, stages.length - 1);
          return { ...ld, stage: stages[nextIndex] };
        }
        return ld;
      })
    );
    triggerToast('Lead pipeline stage promoted successfully.');
  };

  const handleForceSync = (id: string) => {
    setLeads((prev) =>
      prev.map((ld) => (ld.id === id ? { ...ld, status: 'SYNCING' } : ld))
    );

    setTimeout(() => {
      setLeads((prev) =>
        prev.map((ld) => {
          if (ld.id === id) {
            return {
              ...ld,
              status: 'SUCCESS',
              sfId: ld.sfId || `00Q8a00000${Math.random().toString(36).substring(2, 10).toUpperCase()}AAU`,
              lastSynced: 'Just now',
              errorMessage: undefined
            };
          }
          return ld;
        })
      );

      const timeStr = new Date().toLocaleTimeString('en-US', { hour12: false });
      const forceLog: ComplianceAuditLog = {
        id: `l-sim-force-${Date.now()}`,
        timestamp: timeStr,
        event: 'TOKEN_CACHE_HIT',
        actor: 'salesforce-sync-processor',
        details: 'Forced bi-directional REST sync completed successfully. Mappings aligned.',
        severity: 'INFO'
      };
      setLogs((prev) => [forceLog, ...prev]);
      triggerToast('Force sync completed successfully.');
    }, 1200);
  };

  // Filters
  const filteredLogs = useMemo(() => {
    return logs.filter((log) => {
      const matchSearch = `${log.event} ${log.details} ${log.actor}`.toLowerCase().includes(searchQuery.toLowerCase());
      if (logFilter === 'ALL') return matchSearch;
      return matchSearch && log.severity === logFilter;
    });
  }, [logs, searchQuery, logFilter]);

  const getPiiComparison = (alias: string) => {
    return {
      sourcedLead: {
        id: 'l-48a12b',
        alias: alias,
        contact_number: '+91 98765 43210',
        buyer_full_name: 'Jitu Lalit Gupta',
        whatsapp_link: 'https://wa.me/919876543210',
        stage: 'visit_verified'
      },
      outboundRestPayload: {
        lead_uuid: 'l-48a12b',
        lead_alias: alias,
        visit_verified_status: true,
        restricted_buyer_identity: 'DATALESS_COMPLIANT_ZERO_PII',
        caller_phone_parameters: 'REMOVED_FROM_OUTBOUND_STREAM'
      }
    };
  };

  return (
    <div className={styles.container}>
      <div className={styles.ambientGlow1} />
      <div className={styles.ambientGlow2} />

      <div className={styles.wrapper}>
        {/* Dynamic Toast */}
        {toastMessage && (
          <div className="fixed top-6 right-6 py-2.5 px-4 rounded-lg bg-[#131c27]/90 border border-emerald-500/20 text-xs text-emerald-300 flex items-center justify-between gap-3 shadow-lg shadow-black/40 z-50 animate-bounce">
            <div className="flex items-center gap-2">
              <Zap className="w-4 h-4 text-emerald-400 animate-pulse" />
              <span>{toastMessage}</span>
            </div>
            <button onClick={() => setToastMessage(null)} className="text-slate-500 hover:text-white">
              <X className="w-3.5 h-3.5" />
            </button>
          </div>
        )}

        {/* Unified Header */}
        <header className={styles.header}>
          <div className={styles.brandGroup}>
            <div className={styles.logoIcon}>
              <ArrowRightLeft className="w-7 h-7" />
            </div>
            <div>
              <div className="flex items-center gap-3">
                <h1 className={styles.brandTitle}>Sourcing Manager OS</h1>
                <span className={styles.badge}>Strategic Hub</span>
              </div>
              <p className="text-xs text-slate-400">All-in-One Lead Management & Cryptographic Compliance Control Center</p>
            </div>
          </div>

          <div className={styles.systemStatus}>
            <div className={styles.statusIndicator}>
              <div className={styles.pulseDot} />
              <span>COMPLIANCE VAULT ONLINE</span>
            </div>
            <div className="text-right font-mono text-[10px] text-slate-500">
              <div>API VERSION: REST-v57.0</div>
              <div>LAST SECURE SYNC: RECENT</div>
            </div>
          </div>
        </header>

        {/* Bento Stats Grid */}
        <div className={styles.bentoGrid}>
          {/* Card 1 */}
          <div className={`${styles.bentoCard} col-span-12 sm:col-span-6 lg:col-span-3`}>
            <div className={styles.cardHeader}>
              <span className={styles.cardTitle}>Total Managed Assets</span>
              <Database className={styles.cardIcon} size={18} />
            </div>
            <span className={styles.cardValue}>248</span>
            <div className={styles.cardSubtext}>
              <span>Active Sourced Leads</span>
            </div>
          </div>

          {/* Card 2 */}
          <div className={`${styles.bentoCard} col-span-12 sm:col-span-6 lg:col-span-3`}>
            <div className={styles.cardHeader}>
              <span className={styles.cardTitle}>Salesforce Adaptor Health</span>
              <TrendingUp className="text-[#3b82f6]" size={18} />
            </div>
            <span className={styles.cardValue}>99.8%</span>
            <div className={styles.cardSubtext}>
              <span>Sync Success rate</span>
            </div>
          </div>

          {/* Card 3 */}
          <div className={`${styles.bentoCard} col-span-12 sm:col-span-6 lg:col-span-3`}>
            <div className={styles.cardHeader}>
              <span className={styles.cardTitle}>PII Isolation Guard</span>
              <ShieldCheck className="text-emerald-400" size={18} />
            </div>
            <span className={styles.cardValue}>0.0%</span>
            <div className={styles.cardSubtext}>
              <span className="text-emerald-400 font-bold bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                100% ENCRYPTED
              </span>
            </div>
          </div>

          {/* Card 4 */}
          <div className={`${styles.bentoCard} col-span-12 sm:col-span-6 lg:col-span-3`}>
            <div className={styles.cardHeader}>
              <span className={styles.cardTitle}>Committed SObjects</span>
              <UserCheck className="text-violet-400" size={18} />
            </div>
            <span className={styles.cardValue}>142</span>
            <div className={styles.cardSubtext}>
              <span>Active mappings verified</span>
            </div>
          </div>
        </div>

        {/* Split Workflow Views */}
        <div className={styles.splitView}>
          {/* Left Panel: Sourced Leads Management */}
          <div className={styles.bentoCard}>
            <div className={styles.sectionHeader}>
              <h2 className={styles.sectionTitle}>
                <Database className="w-5 h-5 text-[#10b981]" /> Leads Pipeline & Quality Management
              </h2>
              <span className="text-xs text-slate-400 font-bold">REAL-TIME VAULT CONTROLS</span>
            </div>

            <div className={styles.pipelineContainer}>
              {leads.map((ld) => (
                <div key={ld.id} className={styles.leadRow}>
                  <div className={styles.leadMeta}>
                    <div className="flex items-center gap-2">
                      <span className={styles.leadAlias}>{ld.alias}</span>
                      <span className={`${styles.qualityPill} ${
                        ld.quality === 'Hot' ? styles.qualityHot : ld.quality === 'Warm' ? styles.qualityWarm : styles.qualityCold
                      }`}>{ld.quality} Quality</span>
                    </div>
                    <div className={styles.leadDetails}>
                      <span>Area: <strong className="text-slate-200">{ld.area}</strong></span>
                      <span>•</span>
                      <span>Project: <strong className="text-slate-200">{ld.project}</strong></span>
                    </div>
                  </div>

                  <div className="flex items-center gap-4">
                    <span className={`${styles.stageBadge} ${
                      ld.stage === 'Intake' ? styles.stageIntake : ld.stage === 'Assigned' ? styles.stageAssigned : ld.stage === 'Visit Verified' ? styles.stageIntake : styles.stageLocked
                    }`}>{ld.stage}</span>

                    <div className={styles.leadActions}>
                      <button onClick={() => setSelectedLead(ld)} className={styles.btnActionSecondary} title="Audit Payload">
                        <Eye size={12} className="mr-1 inline" /> Payload
                      </button>
                      <button onClick={() => handlePromoteStage(ld.id)} className={styles.btnAction} title="Promote Stage">
                        <TrendingUp size={12} className="mr-1 inline" /> Promote
                      </button>
                      <button onClick={() => handleForceSync(ld.id)} className={styles.btnAction} title="Force Sync">
                        <RefreshCw size={12} className="mr-1 inline" /> Sync
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Right Panel: Webhook volume chart and sandboxes */}
          <div className="space-y-6">
            {/* SVG Activity Graph */}
            <div className={styles.bentoCard}>
              <div className={styles.cardHeader}>
                <span className={styles.cardTitle}>Webhook Ingestion Volume (24h)</span>
                <Activity className="text-[#10b981]" size={16} />
              </div>
              
              <div className={styles.chartContainer}>
                <svg viewBox="0 0 400 150" className={styles.svgChart}>
                  <line x1="0" y1="20" x2="400" y2="20" stroke="rgba(255,255,255,0.03)" strokeWidth="1" />
                  <line x1="0" y1="60" x2="400" y2="60" stroke="rgba(255,255,255,0.03)" strokeWidth="1" />
                  <line x1="0" y1="100" x2="400" y2="100" stroke="rgba(255,255,255,0.03)" strokeWidth="1" />
                  
                  <path
                    d="M 0,110 Q 50,40 100,80 T 200,30 T 300,70 T 400,20"
                    fill="none"
                    stroke="#10b981"
                    strokeWidth="3"
                    strokeLinecap="round"
                    className="drop-shadow-[0_0_8px_rgba(16,185,129,0.3)]"
                  />
                  
                  <circle cx="100" cy="80" r="3.5" fill="#10b981" />
                  <circle cx="200" cy="30" r="3.5" fill="#10b981" />
                  <circle cx="300" cy="70" r="3.5" fill="#10b981" />
                </svg>
              </div>
            </div>

            {/* Sandbox Operations */}
            <div className={styles.bentoCard}>
              <div className={styles.sectionHeader}>
                <h3 className={styles.sectionTitle}>
                  <Zap className="w-5 h-5 text-amber-500" /> Integration Simulation Controls
                </h3>
              </div>

              <div className="space-y-4">
                <div className={styles.controlCard}>
                  <span className={styles.controlLabel}>partner webhook ingestion</span>
                  <p className={styles.controlDescription}>Push a new external CRM lead update. Authenticates signature, decrypts inputs, and writes to Vault.</p>
                  <button onClick={handleSimulateWebhook} className={`${styles.btn} ${styles.btnPrimary} w-full`}>
                    <Play size={12} /> Post Signed Webhook
                  </button>
                </div>

                <div className={styles.controlCard}>
                  <span className={styles.controlLabel}>security threat spoof block</span>
                  <p className={styles.controlDescription}>Spoof an inbound post with a forged cryptographical header. Validates active fail-closed blocks.</p>
                  <button onClick={handleSimulateAttack} className={`${styles.btn} ${styles.btnSecondary} w-full text-rose-400 border-rose-500/20 hover:bg-rose-950/10`}>
                    <ShieldAlert size={12} /> Test Forged HMAC Webhook
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Section: Audit Logs & Security Records */}
        <div className={styles.bentoCard}>
          <div className={styles.sectionHeader}>
            <div className="flex flex-col gap-1.5">
              <h2 className={styles.sectionTitle}>
                <ShieldCheck className="w-5 h-5 text-emerald-400" /> Compliance Audit Trail & Verification Streams
              </h2>
              <p className="text-[11px] text-slate-500">Immutable transactional log entries proving cryptographically secure dataless compliance.</p>
            </div>
            
            {/* Log filter */}
            <div className="flex gap-1.5 p-1 bg-slate-950/60 border border-slate-900 rounded-lg">
              {['ALL', 'INFO', 'SECURE', 'WARNING'].map((f) => (
                <button
                  key={f}
                  onClick={() => setLogFilter(f)}
                  className={`px-3 py-1 rounded text-[10px] font-bold transition-all ${
                    logFilter === f
                      ? 'bg-[#1c242e] text-[#10b981] border border-slate-800'
                      : 'text-slate-500 hover:text-slate-300'
                  }`}
                >
                  {f}
                </button>
              ))}
            </div>
          </div>

          {/* Log Stream */}
          <div className={styles.logFeed}>
            {filteredLogs.map((log) => (
              <div key={log.id} className={styles.logRow}>
                <div className={styles.logMeta}>
                  {log.severity === 'WARNING' ? (
                    <ShieldAlert className="text-rose-500" size={14} />
                  ) : (
                    <ShieldCheck className={log.severity === 'SECURE' ? 'text-emerald-400' : 'text-slate-500'} size={14} />
                  )}
                  <div className={styles.logTextGroup}>
                    <span className={styles.logTitle}>{log.event}</span>
                    <span className={styles.logTimestamp}>[{log.timestamp}] actor: {log.actor}</span>
                    <p className="text-[11px] text-slate-400 mt-1 leading-normal font-sans">{log.details}</p>
                  </div>
                </div>
                <span className={`${styles.logBadge} ${
                  log.severity === 'SECURE' ? styles.badgeSecure : log.severity === 'WARNING' ? styles.badgeReject : styles.badgeAuth
                }`}>{log.severity}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Comparison Drawer / Modal */}
      {selectedLead && (
        <div className={styles.modalOverlay} onClick={() => setSelectedLead(null)}>
          <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h3 className={styles.modalTitle}>PII Extraction Comparative Audit Drawer</h3>
              <button className={styles.closeBtn} onClick={() => setSelectedLead(null)}>
                <X className="w-5 h-5" />
              </button>
            </div>

            <p className="text-xs text-slate-400 leading-normal">
              Compare the internal sourced lead context (containing sensitive data attributes) with the actual dataless REST payload transmitted to the Salesforce integration Connected App for **{selectedLead.alias}**.
            </p>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <span className="text-[10px] text-rose-400 font-bold uppercase tracking-wider block">
                  ⚠️ Internal Lead Parameters (Restricted)
                </span>
                <pre className={styles.codeBlock}>
                  {JSON.stringify(getPiiComparison(selectedLead.alias).sourcedLead, null, 2)}
                </pre>
              </div>

              <div className="space-y-1.5">
                <span className="text-[10px] text-emerald-400 font-bold uppercase tracking-wider block">
                  🛡️ Outbound Salesforce REST Payload
                </span>
                <pre className={styles.codeBlock}>
                  {JSON.stringify(getPiiComparison(selectedLead.alias).outboundRestPayload, null, 2)}
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

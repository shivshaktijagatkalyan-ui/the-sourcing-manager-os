'use client';

import React, { FormEvent, useMemo, useState } from 'react';
import {
  AlertTriangle,
  BadgeCheck,
  BriefcaseBusiness,
  CalendarClock,
  ChevronDown,
  CheckCircle2,
  ChevronRight,
  ChevronUp,
  ClipboardCheck,
  Clock3,
  Flame,
  Gauge,
  HandCoins,
  KeyRound,
  Layers3,
  LockKeyhole,
  MessageSquareWarning,
  PhoneCall,
  Plus,
  RotateCw,
  Route,
  ShieldCheck,
  Sparkles,
  Target,
  UserCheck,
  Users,
  X,
} from 'lucide-react';

type LeadQuality = 'Hot' | 'Warm' | 'Cold';
type DataLoanStatus = 'Active' | 'Expired' | 'Revoked' | 'Inactive';
type VisitStatus =
  | 'Not Scheduled'
  | 'Proposed'
  | 'Scheduled'
  | 'Proof Pending'
  | 'Verified'
  | 'Disputed';
type LockStatus = 'Not Started' | 'Pending' | 'Active' | 'Expired' | 'Blocked';
type BookingStage =
  | 'Not Started'
  | 'Booking Discussion'
  | 'Token Discussion'
  | 'Token Paid'
  | 'Booking Confirmed'
  | 'Lost';
type BrokerageStatus =
  | 'Tracking'
  | 'Pending Visit'
  | 'Locked'
  | 'Eligible'
  | 'Paid'
  | 'Disputed'
  | 'Blocked';

type LeadFilter =
  | 'All'
  | 'Needs Action'
  | 'Expired Access'
  | 'Unassigned'
  | 'Hot'
  | 'Warm'
  | 'Follow-up Due'
  | 'Visit Pending'
  | 'Lock';
type LeadSort = 'Smart Priority' | 'Follow-up First' | 'Newest Updated' | 'Most Calls' | 'Alias A-Z';

interface BrokerLead {
  id: string;
  alias: string;
  project: string;
  area: string;
  city: string;
  budget: string;
  buyerType: 'End User' | 'Investor' | 'Family Decision';
  assignedTo: string;
  assignedRole: 'Caller' | 'Sourcing Manager' | 'Unassigned';
  dataLoan: DataLoanStatus;
  loanExpiresAt?: string;
  callStatus: string;
  visitStatus: VisitStatus;
  brokerLock: LockStatus;
  lockExpiresAt?: string;
  bookingStage: BookingStage;
  brokerageStatus: BrokerageStatus;
  leadQuality: LeadQuality;
  dataQuality: 'Strong' | 'Medium' | 'Weak';
  followupAt?: string;
  callsAttempted: number;
  nextAction: string;
  lastUpdated: string;
}

interface ActivityRow {
  id: string;
  kind: string;
  leadAlias?: string;
  body: string;
  at: string;
}

interface VisitProposal {
  id: string;
  leadAlias: string;
  project: string;
  proposedFor: string;
  status: 'Proposed' | 'Accepted' | 'Rejected' | 'Verified';
  notes: string;
}

interface ProjectRow {
  id: string;
  name: string;
  developer: string;
  area: string;
  stage: string;
  manager: string;
  activeLeads: number;
  verifiedVisits: number;
  capacity: number;
}

interface WorkforceMember {
  id: string;
  name: string;
  role: 'Caller' | 'Sourcing Manager';
  zone: string;
  capacity: number;
  activeLoad: number;
  status: 'Active' | 'Paused';
}

interface AddLeadForm {
  alias: string;
  oneTimePhone: string;
  area: string;
  city: string;
  project: string;
  budgetMin: string;
  budgetMax: string;
  buyerType: BrokerLead['buyerType'];
}

const now = new Date('2026-05-19T11:00:00+05:30');

const baseInitialLeads: BrokerLead[] = [
  {
    id: 'lead-1042',
    alias: 'L-1042',
    project: 'Wadhwa Wise City',
    area: 'Mira Road',
    city: 'Mumbai',
    budget: 'Rs. 80L - Rs. 1Cr',
    buyerType: 'End User',
    assignedTo: 'Rahul Caller',
    assignedRole: 'Caller',
    dataLoan: 'Active',
    loanExpiresAt: addHours(now, 7),
    callStatus: 'Interested',
    visitStatus: 'Scheduled',
    brokerLock: 'Pending',
    bookingStage: 'Booking Discussion',
    brokerageStatus: 'Tracking',
    leadQuality: 'Hot',
    dataQuality: 'Strong',
    followupAt: addHours(now, 3),
    callsAttempted: 2,
    nextAction: 'Confirm site visit timing',
    lastUpdated: addHours(now, -2),
  },
  {
    id: 'lead-1088',
    alias: 'L-1088',
    project: 'Wadhwa Wise City',
    area: 'Bhayandar',
    city: 'Mumbai',
    budget: 'Rs. 65L - Rs. 85L',
    buyerType: 'Family Decision',
    assignedTo: 'Vinod SM',
    assignedRole: 'Sourcing Manager',
    dataLoan: 'Expired',
    loanExpiresAt: addHours(now, -4),
    callStatus: 'Call Later',
    visitStatus: 'Not Scheduled',
    brokerLock: 'Not Started',
    bookingStage: 'Not Started',
    brokerageStatus: 'Tracking',
    leadQuality: 'Warm',
    dataQuality: 'Medium',
    followupAt: addHours(now, 5),
    callsAttempted: 1,
    nextAction: 'Renew call access',
    lastUpdated: addHours(now, -8),
  },
  {
    id: 'lead-1120',
    alias: 'L-1120',
    project: 'Wadhwa Wise City',
    area: 'Mira Road',
    city: 'Mumbai',
    budget: 'Rs. 1Cr - Rs. 1.25Cr',
    buyerType: 'Investor',
    assignedTo: 'Rahul Caller',
    assignedRole: 'Caller',
    dataLoan: 'Revoked',
    callStatus: 'Not Reachable',
    visitStatus: 'Disputed',
    brokerLock: 'Blocked',
    bookingStage: 'Lost',
    brokerageStatus: 'Blocked',
    leadQuality: 'Cold',
    dataQuality: 'Weak',
    callsAttempted: 3,
    nextAction: 'Review issue',
    lastUpdated: addHours(now, -26),
  },
  {
    id: 'lead-1177',
    alias: 'L-1177',
    project: 'Lodha Amara',
    area: 'Thane',
    city: 'Mumbai',
    budget: 'Rs. 90L - Rs. 1.10Cr',
    buyerType: 'End User',
    assignedTo: 'Vinod SM',
    assignedRole: 'Sourcing Manager',
    dataLoan: 'Active',
    loanExpiresAt: addHours(now, 18),
    callStatus: 'Interested',
    visitStatus: 'Not Scheduled',
    brokerLock: 'Not Started',
    bookingStage: 'Not Started',
    brokerageStatus: 'Tracking',
    leadQuality: 'Hot',
    dataQuality: 'Strong',
    followupAt: addHours(now, 24),
    callsAttempted: 1,
    nextAction: 'Propose verified site visit',
    lastUpdated: addHours(now, -1),
  },
];

const initialLeads: BrokerLead[] = [...baseInitialLeads, ...buildScaleLeadVault(1000)];

const initialProjects: ProjectRow[] = [
  {
    id: 'project-wise-city',
    name: 'Wadhwa Wise City',
    developer: 'Wadhwa Group',
    area: 'Panvel',
    stage: 'Active Broker',
    manager: 'Vinod Gupta',
    activeLeads: 503,
    verifiedVisits: 1,
    capacity: 380,
  },
  {
    id: 'project-lodha-amara',
    name: 'Lodha Amara',
    developer: 'Lodha Group',
    area: 'Thane',
    stage: 'Proposal Ready',
    manager: 'Vinod Gupta',
    activeLeads: 501,
    verifiedVisits: 0,
    capacity: 240,
  },
];

const initialWorkforce: WorkforceMember[] = [
  {
    id: 'caller-rahul',
    name: 'Rahul Caller',
    role: 'Caller',
    zone: 'Mira Road',
    capacity: 120,
    activeLoad: 34,
    status: 'Active',
  },
  {
    id: 'sm-vinod',
    name: 'Vinod SM',
    role: 'Sourcing Manager',
    zone: 'Panvel',
    capacity: 70,
    activeLoad: 22,
    status: 'Active',
  },
];

const smExpansionPack: WorkforceMember[] = [
  { id: 'sm-aarti', name: 'Aarti SM', role: 'Sourcing Manager', zone: 'Thane', capacity: 65, activeLoad: 0, status: 'Active' },
  { id: 'sm-sameer', name: 'Sameer SM', role: 'Sourcing Manager', zone: 'Bhayandar', capacity: 60, activeLoad: 0, status: 'Active' },
  { id: 'sm-neha', name: 'Neha SM', role: 'Sourcing Manager', zone: 'Mira Road', capacity: 60, activeLoad: 0, status: 'Active' },
  { id: 'sm-imran', name: 'Imran SM', role: 'Sourcing Manager', zone: 'Panvel', capacity: 55, activeLoad: 0, status: 'Active' },
  { id: 'sm-kavya', name: 'Kavya SM', role: 'Sourcing Manager', zone: 'Central Mumbai', capacity: 55, activeLoad: 0, status: 'Active' },
];

const developerExpansionPack: ProjectRow[] = [
  { id: 'project-godrej-city', name: 'Godrej City', developer: 'Godrej Properties', area: 'Panvel', stage: 'Inventory Ready', manager: 'Aarti SM', activeLeads: 0, verifiedVisits: 0, capacity: 310 },
  { id: 'project-piramal-vaikunth', name: 'Piramal Vaikunth', developer: 'Piramal Realty', area: 'Thane', stage: 'Broker Invite', manager: 'Kavya SM', activeLeads: 0, verifiedVisits: 0, capacity: 220 },
  { id: 'project-runwal-garden', name: 'Runwal Garden', developer: 'Runwal Group', area: 'Dombivli', stage: 'Broker Invite', manager: 'Sameer SM', activeLeads: 0, verifiedVisits: 0, capacity: 260 },
  { id: 'project-raymond-ten-x', name: 'Raymond Ten X', developer: 'Raymond Realty', area: 'Thane', stage: 'Policy Review', manager: 'Neha SM', activeLeads: 0, verifiedVisits: 0, capacity: 180 },
  { id: 'project-kalpataru-parkcity', name: 'Kalpataru Parkcity', developer: 'Kalpataru', area: 'Thane', stage: 'Policy Review', manager: 'Imran SM', activeLeads: 0, verifiedVisits: 0, capacity: 210 },
];

const initialProposals: VisitProposal[] = [
  {
    id: 'proposal-998',
    leadAlias: 'L-998',
    project: 'Wadhwa Wise City',
    proposedFor: addHours(now, 27),
    status: 'Proposed',
    notes: 'Buyer prefers afternoon slot.',
  },
];

const initialActivity: ActivityRow[] = [
  {
    id: 'act-1',
    kind: 'lead_received',
    leadAlias: 'L-1177',
    body: 'Broker lead received with safe metadata.',
    at: addHours(now, -1),
  },
  {
    id: 'act-2',
    kind: 'data_loan_granted',
    leadAlias: 'L-1042',
    body: 'Call access active for assigned caller.',
    at: addHours(now, -4),
  },
  {
    id: 'act-3',
    kind: 'site_visit_scheduled',
    leadAlias: 'L-1042',
    body: 'Site visit scheduled for sourcing manager coordination.',
    at: addHours(now, -6),
  },
];

const defaultLeadForm: AddLeadForm = {
  alias: '',
  oneTimePhone: '',
  area: '',
  city: 'Mumbai',
  project: 'Wadhwa Wise City',
  budgetMin: '',
  budgetMax: '',
  buyerType: 'End User',
};

export default function BrokerDashboardFutureTrust() {
  const [leads, setLeads] = useState<BrokerLead[]>(initialLeads);
  const [projects, setProjects] = useState<ProjectRow[]>(initialProjects);
  const [workforce, setWorkforce] = useState<WorkforceMember[]>(initialWorkforce);
  const [proposals, setProposals] = useState<VisitProposal[]>(initialProposals);
  const [activity, setActivity] = useState<ActivityRow[]>(initialActivity);
  const [selectedLeadId, setSelectedLeadId] = useState(initialLeads[0].id);
  const [filter, setFilter] = useState<LeadFilter>('All');
  const [leadSort, setLeadSort] = useState<LeadSort>('Smart Priority');
  const [leadSearch, setLeadSearch] = useState('');
  const [projectFilter, setProjectFilter] = useState('All Projects');
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [isVisitSummaryOpen, setIsVisitSummaryOpen] = useState(false);
  const [visibleLeadCount, setVisibleLeadCount] = useState(12);
  const [expandedLeadIds, setExpandedLeadIds] = useState<Set<string>>(new Set());
  const [leadForm, setLeadForm] = useState<AddLeadForm>(defaultLeadForm);
  const [followupAt, setFollowupAt] = useState('');
  const [proposalAt, setProposalAt] = useState('');
  const [proposalNotes, setProposalNotes] = useState('');
  const [notice, setNotice] = useState('Dashboard ready. All contact-sensitive actions stay behind governed workflows.');

  const selectedLead = leads.find((lead) => lead.id === selectedLeadId) ?? leads[0];
  const stats = useMemo(() => buildStats(leads, proposals), [leads, proposals]);
  const priorities = useMemo(() => buildPriorityActions(leads), [leads]);
  const operations = useMemo(() => buildOperationsSnapshot(leads, workforce, projects), [leads, workforce, projects]);
  const projectOptions = useMemo(() => ['All Projects', ...projects.map((project) => project.name)], [projects]);
  const expiredLeads = useMemo(() => leads.filter((lead) => lead.dataLoan === 'Expired'), [leads]);
  const verifiedVisitLeads = useMemo(() => leads.filter((lead) => lead.visitStatus === 'Verified'), [leads]);
  const followupRows = useMemo(() => buildFollowupRows(leads), [leads]);
  const queueCounts = useMemo(() => buildLeadQueueCounts(leads), [leads]);

  const filteredLeads = useMemo(() => {
    const search = leadSearch.trim().toLowerCase();
    const rows = leads.filter((lead) => {
      if (filter === 'Needs Action' && !needsBrokerAction(lead)) return false;
      if (filter === 'Expired Access' && lead.dataLoan !== 'Expired') return false;
      if (filter === 'Unassigned' && lead.assignedRole !== 'Unassigned') return false;
      if (filter === 'Hot' && lead.leadQuality !== 'Hot') return false;
      if (filter === 'Warm' && lead.leadQuality !== 'Warm') return false;
      if (filter === 'Follow-up Due' && !isFollowupDue(lead)) return false;
      if (filter === 'Visit Pending' && (lead.callStatus !== 'Interested' || lead.visitStatus !== 'Not Scheduled')) return false;
      if (filter === 'Lock' && lead.brokerLock !== 'Active' && lead.brokerLock !== 'Pending') return false;
      if (projectFilter !== 'All Projects' && lead.project !== projectFilter) return false;
      if (!search) return true;
      return [lead.alias, lead.project, lead.area, lead.assignedTo, lead.nextAction]
        .join(' ')
        .toLowerCase()
        .includes(search);
    });
    return sortLeads(rows, leadSort);
  }, [filter, leadSearch, projectFilter, leadSort, leads]);

  const displayedLeads = filteredLeads.slice(0, visibleLeadCount);
  const topPriorityLeads = useMemo(
    () => sortLeads(leads.filter(needsBrokerAction), 'Smart Priority').slice(0, 3),
    [leads],
  );

  const recordActivity = (kind: string, body: string, leadAlias?: string) => {
    setActivity((rows) => [
      {
        id: `act-${Date.now()}`,
        kind,
        leadAlias,
        body,
        at: new Date().toISOString(),
      },
      ...rows,
    ]);
  };

  const updateLead = (leadId: string, updater: (lead: BrokerLead) => BrokerLead) => {
    setLeads((rows) =>
      rows.map((lead) =>
        lead.id === leadId
          ? updater({ ...lead, lastUpdated: new Date().toISOString() })
          : lead,
      ),
    );
  };

  const toggleLeadDetails = (leadId: string) => {
    setExpandedLeadIds((current) => {
      const next = new Set(current);
      if (next.has(leadId)) {
        next.delete(leadId);
      } else {
        next.add(leadId);
      }
      return next;
    });
  };

  const setLeadFilter = (nextFilter: LeadFilter) => {
    setFilter(nextFilter);
    setVisibleLeadCount(12);
  };

  const focusLead = (leadId: string) => {
    setSelectedLeadId(leadId);
    setExpandedLeadIds((current) => new Set(current).add(leadId));
    setNotice('Lead selected. Use the command panel to call, renew access, schedule follow-up, or move visit workflow.');
  };

  const renewLeadAccess = (leadId: string) => {
    const lead = leads.find((row) => row.id === leadId);
    if (!lead) return;
    const caller = pickLeastLoadedWorkforce(workforce.filter((member) => member.role === 'Caller' && member.status === 'Active'), leads, lead.area);
    updateLead(leadId, (row) => ({
      ...row,
      assignedTo: caller?.name ?? row.assignedTo,
      assignedRole: caller ? 'Caller' : row.assignedRole,
      dataLoan: 'Active',
      loanExpiresAt: addHours(new Date(), 24),
      nextAction: 'Secure call due',
    }));
    setSelectedLeadId(leadId);
    recordActivity('data_loan_renewed', 'Expired call access renewed for 24 hours.', lead.alias);
    setNotice(`Call access renewed for ${lead.alias}.`);
  };

  const handleStatTap = (label: string, value: number) => {
    switch (label) {
      case 'Hot':
        setLeadFilter('Hot');
        setNotice('Lead command center filtered to hot leads.');
        return;
      case 'Due':
        setLeadFilter('Follow-up Due');
        setNotice('Lead command center filtered to due follow-ups.');
        return;
      case 'Visits':
        setIsVisitSummaryOpen(true);
        return;
      default:
        setNotice(`${label}: ${value} item(s) in this broker workspace.`);
    }
  };

  const handleAddLead = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const cleanPhone = leadForm.oneTimePhone.trim();
    const phoneIsValid = /^\+?[0-9]{10,15}$/.test(cleanPhone);
    const min = Number(leadForm.budgetMin || 0);
    const max = Number(leadForm.budgetMax || 0);

    if (!leadForm.alias.trim() || !leadForm.area.trim() || !phoneIsValid || (min > 0 && max > 0 && max < min)) {
      setNotice('Lead intake blocked. Alias, valid one-time phone, area, and budget order are required.');
      return;
    }

    const budget =
      min > 0 || max > 0
        ? `Rs. ${Math.round(min / 100000)}L - Rs. ${Math.round(max / 100000)}L`
        : 'Budget not set';

    const lead: BrokerLead = {
      id: `lead-${Date.now()}`,
      alias: leadForm.alias.trim(),
      project: leadForm.project,
      area: leadForm.area.trim(),
      city: leadForm.city.trim() || 'Mumbai',
      budget,
      buyerType: leadForm.buyerType,
      assignedTo: 'Unassigned',
      assignedRole: 'Unassigned',
      dataLoan: 'Inactive',
      callStatus: 'Not Called',
      visitStatus: 'Not Scheduled',
      brokerLock: 'Not Started',
      bookingStage: 'Not Started',
      brokerageStatus: 'Tracking',
      leadQuality: 'Warm',
      dataQuality: min > 0 && max > 0 ? 'Medium' : 'Weak',
      callsAttempted: 0,
      nextAction: 'Assign caller or sourcing manager',
      lastUpdated: new Date().toISOString(),
    };

    setLeads((rows) => [lead, ...rows]);
    setProjects((rows) =>
      rows.map((project) =>
        project.name === lead.project
          ? { ...project, activeLeads: project.activeLeads + 1 }
          : project,
      ),
    );
    setSelectedLeadId(lead.id);
    recordActivity('broker_vault_lead_submitted', 'Lead secured. One-time contact value cleared after intake.', lead.alias);
    setLeadForm(defaultLeadForm);
    setIsAddOpen(false);
    setNotice(`${lead.alias} secured in broker vault. Contact value was not stored in dashboard state.`);
  };

  const attachFiveSourcingManagers = () => {
    const existingIds = new Set(workforce.map((member) => member.id));
    const additions = smExpansionPack.filter((member) => !existingIds.has(member.id));

    if (additions.length === 0) {
      setNotice('All five sourcing managers are already attached to BRK-JSN-0001.');
      return;
    }

    setWorkforce((rows) => [...rows, ...additions]);
    recordActivity('broker_sm_capacity_attached', `${additions.length} sourcing managers attached to broker-governed queue.`);
    setNotice(`${additions.length} sourcing managers attached. They receive assigned aliases only, not broker lead ownership.`);
  };

  const attachFiveDevelopers = () => {
    const existingIds = new Set(projects.map((project) => project.id));
    const additions = developerExpansionPack.filter((project) => !existingIds.has(project.id));

    if (additions.length === 0) {
      setNotice('All five developer projects are already attached to this broker workspace.');
      return;
    }

    setProjects((rows) => [...rows, ...additions]);
    recordActivity('broker_developer_routes_attached', `${additions.length} developer project routes attached to broker account.`);
    setNotice(`${additions.length} developer routes attached. Developers see verified traffic and proof states, not raw broker leads.`);
  };

  const routeNextBatch = () => {
    const activeWorkforce = workforce.filter((member) => member.status === 'Active');
    if (activeWorkforce.length === 0) {
      setNotice('Batch routing blocked. Attach an active caller or sourcing manager first.');
      return;
    }

    const eligibleLeads = leads
      .filter((lead) => lead.brokerageStatus !== 'Blocked' && lead.brokerLock !== 'Active')
      .filter((lead) => lead.assignedRole === 'Unassigned' || lead.dataLoan === 'Expired' || lead.nextAction.includes('Assign'))
      .slice(0, 50);

    if (eligibleLeads.length === 0) {
      setNotice('No eligible aliases need batch routing right now.');
      return;
    }

    const activeCallers = activeWorkforce.filter((member) => member.role === 'Caller');
    const activeManagers = activeWorkforce.filter((member) => member.role === 'Sourcing Manager');

    setLeads((rows) =>
      rows.map((lead) => {
        if (!eligibleLeads.some((eligible) => eligible.id === lead.id)) return lead;
        const shouldRouteToManager = lead.leadQuality === 'Hot' || lead.visitStatus !== 'Not Scheduled';
        const memberPool = shouldRouteToManager && activeManagers.length > 0 ? activeManagers : activeCallers.length > 0 ? activeCallers : activeManagers;
        const assignee = pickLeastLoadedWorkforce(memberPool, rows, lead.area);
        if (!assignee) return lead;

        return {
          ...lead,
          assignedTo: assignee.name,
          assignedRole: assignee.role,
          dataLoan: assignee.role === 'Caller' ? 'Active' : lead.dataLoan,
          loanExpiresAt: assignee.role === 'Caller' ? addHours(new Date(), 24) : lead.loanExpiresAt,
          callStatus: assignee.role === 'Caller' && lead.callStatus === 'Not Called' ? 'Queued' : lead.callStatus,
          nextAction: assignee.role === 'Caller' ? 'Secure call due' : 'Coordinate verified visit',
          lastUpdated: new Date().toISOString(),
        };
      }),
    );

    setWorkforce((rows) =>
      rows.map((member) => {
        const addedLoad = eligibleLeads.filter((lead) => {
          const shouldRouteToManager = lead.leadQuality === 'Hot' || lead.visitStatus !== 'Not Scheduled';
          return shouldRouteToManager ? member.role === 'Sourcing Manager' : member.role === 'Caller';
        }).length;
        return addedLoad > 0 ? { ...member, activeLoad: Math.min(member.capacity, member.activeLoad + Math.ceil(addedLoad / Math.max(1, activeWorkforce.length))) } : member;
      }),
    );

    recordActivity('broker_batch_routed', `${eligibleLeads.length} aliases routed through governed assignment and data-loan rules.`);
    setNotice(`${eligibleLeads.length} leads routed. Caller assignments received 24-hour data loans; SM assignments received alias-only visit queues.`);
  };

  const runAction = (action: string) => {
    if (!selectedLead) return;

    if (action === 'secure_call') {
      if (selectedLead.dataLoan !== 'Active') {
        recordActivity('broker_self_call_blocked', `Secure call blocked because access is ${selectedLead.dataLoan.toLowerCase()}.`, selectedLead.alias);
        setNotice(`Secure call blocked for ${selectedLead.alias}. Renew or grant data loan first.`);
        return;
      }
      updateLead(selectedLead.id, (lead) => ({
        ...lead,
        callStatus: 'Queued',
        callsAttempted: lead.callsAttempted + 1,
        nextAction: 'Capture call outcome',
      }));
      recordActivity('broker_self_call_queued', 'Secure call queued through governed bridge.', selectedLead.alias);
      setNotice(`Secure call queued for ${selectedLead.alias}. No raw phone was exposed.`);
      return;
    }

    if (action === 'grant_access') {
      const caller = pickLeastLoadedWorkforce(workforce.filter((member) => member.role === 'Caller' && member.status === 'Active'), leads, selectedLead.area);
      updateLead(selectedLead.id, (lead) => ({
        ...lead,
        assignedTo: caller?.name ?? 'Rahul Caller',
        assignedRole: 'Caller',
        dataLoan: 'Active',
        loanExpiresAt: addHours(new Date(), 24),
        nextAction: 'Secure call due',
      }));
      recordActivity('data_loan_granted', '24-hour call access granted to active caller.', selectedLead.alias);
      setNotice(`Call access granted for ${selectedLead.alias}.`);
      return;
    }

    if (action === 'extend_access') {
      updateLead(selectedLead.id, (lead) => ({
        ...lead,
        dataLoan: 'Active',
        loanExpiresAt: addHours(new Date(lead.loanExpiresAt ?? Date.now()), 24),
        nextAction: 'Continue caller follow-up',
      }));
      recordActivity('data_loan_extended', 'Call access extended by 24 hours.', selectedLead.alias);
      setNotice(`Call access extended for ${selectedLead.alias}.`);
      return;
    }

    if (action === 'revoke_access') {
      updateLead(selectedLead.id, (lead) => ({
        ...lead,
        dataLoan: 'Revoked',
        loanExpiresAt: undefined,
        nextAction: 'Review access before calling',
      }));
      recordActivity('data_loan_revoked', 'Call access revoked by broker.', selectedLead.alias);
      setNotice(`Call access revoked for ${selectedLead.alias}.`);
      return;
    }

    if (action === 'assign_sm') {
      const manager = pickLeastLoadedWorkforce(workforce.filter((member) => member.role === 'Sourcing Manager' && member.status === 'Active'), leads, selectedLead.area);
      updateLead(selectedLead.id, (lead) => ({
        ...lead,
        assignedTo: manager?.name ?? 'Vinod SM',
        assignedRole: 'Sourcing Manager',
        nextAction: 'Coordinate site visit',
      }));
      recordActivity('lead_assigned_to_sm', 'Lead assigned to sourcing manager for field coordination.', selectedLead.alias);
      setNotice(`${selectedLead.alias} assigned to ${manager?.name ?? 'Vinod SM'}.`);
      return;
    }

    if (action === 'verify_visit') {
      const lockExpiry = addDays(new Date(), 45);
      updateLead(selectedLead.id, (lead) => ({
        ...lead,
        visitStatus: 'Verified',
        brokerLock: 'Active',
        lockExpiresAt: lockExpiry,
        brokerageStatus: 'Locked',
        bookingStage: lead.bookingStage === 'Not Started' ? 'Booking Discussion' : lead.bookingStage,
        nextAction: 'Track booking discussion',
      }));
      setProjects((rows) =>
        rows.map((project) =>
          project.name === selectedLead.project
            ? { ...project, verifiedVisits: project.verifiedVisits + 1 }
            : project,
        ),
      );
      recordActivity('broker_lock_activated', 'Verified visit created 45-day broker lock.', selectedLead.alias);
      setNotice(`Broker lock active for ${selectedLead.alias} until ${formatDate(lockExpiry)}.`);
    }
  };

  const setQuality = (quality: LeadQuality) => {
    if (!selectedLead) return;
    updateLead(selectedLead.id, (lead) => ({
      ...lead,
      leadQuality: quality,
      dataQuality: quality === 'Hot' ? 'Strong' : quality === 'Warm' ? 'Medium' : 'Weak',
      nextAction: quality === 'Hot' ? 'Move to visit proposal' : 'Keep structured follow-up',
    }));
    recordActivity('lead_quality_updated', `Lead quality updated to ${quality}.`, selectedLead.alias);
  };

  const setBookingStage = (bookingStage: BookingStage) => {
    if (!selectedLead) return;
    updateLead(selectedLead.id, (lead) => ({
      ...lead,
      bookingStage,
      nextAction: bookingStage === 'Booking Confirmed' ? 'Review brokerage eligibility' : 'Track booking progress',
    }));
    recordActivity('booking_stage_updated', `Booking stage updated to ${bookingStage}.`, selectedLead.alias);
  };

  const setBrokerageStatus = (brokerageStatus: BrokerageStatus) => {
    if (!selectedLead) return;
    updateLead(selectedLead.id, (lead) => ({
      ...lead,
      brokerageStatus,
      nextAction: brokerageStatus === 'Disputed' ? 'Resolve broker issue' : 'Continue brokerage tracking',
    }));
    recordActivity('brokerage_status_updated', `Brokerage status updated to ${brokerageStatus}.`, selectedLead.alias);
  };

  const setFollowup = () => {
    if (!selectedLead || !followupAt) return;
    updateLead(selectedLead.id, (lead) => ({
      ...lead,
      followupAt,
      callStatus: 'Call Later',
      nextAction: 'Follow-up scheduled',
    }));
    recordActivity('broker_followup_set', `Follow-up set for ${formatDate(followupAt)}.`, selectedLead.alias);
    setNotice(`Follow-up set for ${selectedLead.alias}.`);
    setFollowupAt('');
  };

  const proposeVisit = () => {
    if (!selectedLead || !proposalAt) return;
    const proposal: VisitProposal = {
      id: `proposal-${Date.now()}`,
      leadAlias: selectedLead.alias,
      project: selectedLead.project,
      proposedFor: proposalAt,
      status: 'Proposed',
      notes: scrubContactText(proposalNotes || 'Broker proposed a verified visit slot.'),
    };
    setProposals((rows) => [proposal, ...rows]);
    updateLead(selectedLead.id, (lead) => ({
      ...lead,
      visitStatus: 'Proposed',
      brokerLock: 'Pending',
      brokerageStatus: 'Pending Visit',
      nextAction: 'Wait for sourcing manager approval',
    }));
    recordActivity('site_visit_proposed', `Visit proposed for ${formatDate(proposalAt)}.`, selectedLead.alias);
    setNotice(`Site visit proposed for ${selectedLead.alias}.`);
    setProposalAt('');
    setProposalNotes('');
  };

  const raiseIssue = () => {
    if (!selectedLead) return;
    updateLead(selectedLead.id, (lead) => ({
      ...lead,
      brokerageStatus: 'Disputed',
      nextAction: 'Resolve issue with audit trail',
    }));
    recordActivity('broker_issue_raised', 'Broker raised an attribution/proof review issue.', selectedLead.alias);
    setNotice(`Issue raised for ${selectedLead.alias}.`);
  };

  return (
    <div className="min-h-screen bg-[#071013] text-slate-100">
      <main className="mx-auto flex w-full max-w-7xl flex-col gap-5 px-4 py-4 sm:px-6 lg:px-8">
        <header className="flex flex-col gap-4 border-b border-white/10 pb-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex items-start gap-3">
            <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-emerald-400/15 text-emerald-300 ring-1 ring-emerald-300/25">
              <ShieldCheck size={22} />
            </div>
            <div>
              <h1 className="text-xl font-semibold tracking-normal text-white sm:text-2xl">Broker Business Vault</h1>
              <p className="mt-1 max-w-2xl text-sm leading-6 text-slate-400">
                Jitu Gupta · JSN Enterprise · Mira Road · protected broker attribution workspace
              </p>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <TrustBadge icon={<BadgeCheck size={15} />} label="Verified Active" tone="green" />
            <TrustBadge icon={<Gauge size={15} />} label="Silver Rank" tone="blue" />
            <TrustBadge icon={<LockKeyhole size={15} />} label="PII Vaulted" tone="amber" />
            <button
              type="button"
              onClick={() => setIsAddOpen(true)}
              className="inline-flex h-10 items-center gap-2 rounded-md bg-amber-400 px-3 text-sm font-semibold text-slate-950 transition hover:bg-amber-300 focus:outline-none focus:ring-2 focus:ring-amber-200"
            >
              <Plus size={16} />
              Secure Lead
            </button>
          </div>
        </header>

        <section className="grid gap-3 md:grid-cols-[1.4fr_1fr]">
          <div className="rounded-lg border border-white/10 bg-white/[0.03] p-4">
            <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Broker ID</p>
                <div className="mt-2 flex flex-wrap items-center gap-2">
                  <span className="font-mono text-lg font-semibold text-white">BRK-JSN-0001</span>
                  <span className="rounded-full border border-emerald-300/20 bg-emerald-300/10 px-2 py-1 text-xs font-medium text-emerald-200">
                    98 trust score
                  </span>
                </div>
                <p className="mt-2 text-sm text-slate-400">Connected SM: Vinod Gupta · Focus project: Wadhwa Wise City, Panvel</p>
              </div>
              <div className="grid grid-cols-3 gap-2 text-center">
                <MiniMetric label="Live projects" value={projects.length} />
                <MiniMetric label="Verified visits" value={stats.verifiedVisits} />
                <MiniMetric label="Locks active" value={stats.activeLocks} />
              </div>
            </div>
            <button
              type="button"
              onClick={() => setIsAddOpen(true)}
              className="mt-4 inline-flex h-12 w-full items-center justify-center gap-2 rounded-md bg-amber-400 px-4 text-sm font-semibold text-slate-950 transition hover:bg-amber-300 focus:outline-none focus:ring-2 focus:ring-amber-200"
            >
              <Plus size={17} />
              Add Secure Lead
            </button>
          </div>

          <div className="rounded-lg border border-amber-300/20 bg-amber-300/10 p-4">
            <div className="flex items-start gap-3">
              <Sparkles className="mt-0.5 text-amber-200" size={20} />
              <div>
                <p className="text-sm font-semibold text-amber-100">Best next focus</p>
                <p className="mt-1 text-sm leading-6 text-amber-50/80">
                  Mira Road hot leads are moving fastest. Push visit proposals before access windows expire.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="grid grid-cols-2 gap-3 md:grid-cols-4 xl:grid-cols-8">
          <StatCard icon={<Users size={17} />} label="Leads" value={stats.totalLeads} onClick={() => handleStatTap('Leads', stats.totalLeads)} />
          <StatCard icon={<Flame size={17} />} label="Hot" value={stats.hotLeads} tone="orange" onClick={() => handleStatTap('Hot', stats.hotLeads)} />
          <StatCard icon={<PhoneCall size={17} />} label="Calls" value={stats.callsAttempted} tone="blue" onClick={() => handleStatTap('Calls', stats.callsAttempted)} />
          <StatCard icon={<Clock3 size={17} />} label="Due" value={stats.followupsDue} tone="amber" onClick={() => handleStatTap('Due', stats.followupsDue)} />
          <StatCard icon={<KeyRound size={17} />} label="Loans" value={stats.activeLoans} tone="green" onClick={() => handleStatTap('Loans', stats.activeLoans)} />
          <StatCard icon={<Route size={17} />} label="Visits" value={stats.proposedVisits} tone="purple" onClick={() => handleStatTap('Visits', stats.proposedVisits)} />
          <StatCard icon={<LockKeyhole size={17} />} label="Locks" value={stats.activeLocks} tone="green" onClick={() => handleStatTap('Locks', stats.activeLocks)} />
          <StatCard icon={<HandCoins size={17} />} label="Brokerage" value={stats.brokerageTracking} tone="blue" onClick={() => handleStatTap('Brokerage', stats.brokerageTracking)} />
        </section>

        {expiredLeads.length > 0 && (
          <ExpiredAccessPanel leads={expiredLeads} onRenew={renewLeadAccess} />
        )}

        <section className="grid gap-3 lg:grid-cols-3">
          {priorities.map((priority) => (
            <div key={priority.title} className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
              <div className="flex items-start gap-3">
                <priority.icon className={priority.color} size={20} />
                <div>
                  <p className="text-sm font-semibold text-white">{priority.title}</p>
                  <p className="mt-1 text-sm leading-6 text-slate-400">{priority.body}</p>
                </div>
              </div>
            </div>
          ))}
        </section>

        <ScaleAllocationEngine
          operations={operations}
          leadSearch={leadSearch}
          projectFilter={projectFilter}
          leadSort={leadSort}
          projectOptions={projectOptions}
          workforce={workforce}
          projects={projects}
          onLeadSearchChange={setLeadSearch}
          onProjectFilterChange={setProjectFilter}
          onLeadSortChange={(value) => setLeadSort(value as LeadSort)}
          onAttachSms={attachFiveSourcingManagers}
          onAttachDevelopers={attachFiveDevelopers}
          onRouteBatch={routeNextBatch}
        />

        <div className="grid gap-5 xl:grid-cols-[minmax(0,1.35fr)_minmax(360px,0.65fr)]">
          <section className="min-w-0">
            <div className="mb-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="text-base font-semibold text-white">Protected Lead Command Center</h2>
                <p className="mt-1 text-sm text-slate-500">
                  Showing {displayedLeads.length} of {filteredLeads.length} matched aliases from {leads.length} protected leads. No phone, no export, no direct call link.
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                {(['All', 'Needs Action', 'Expired Access', 'Unassigned', 'Hot', 'Warm', 'Follow-up Due', 'Visit Pending', 'Lock'] as const).map((item) => (
                  <button
                    key={item}
                    type="button"
                    onClick={() => setLeadFilter(item)}
                    className={`h-9 rounded-md px-3 text-sm font-medium transition ${
                      filter === item
                        ? 'bg-white text-slate-950'
                        : 'border border-white/10 bg-white/[0.03] text-slate-300 hover:bg-white/[0.07]'
                    }`}
                  >
                    {item}
                    {item !== 'All' && (
                      <span className="ml-1 rounded bg-black/15 px-1 text-[11px]">
                        {queueCounts[item] ?? 0}
                      </span>
                    )}
                  </button>
                ))}
              </div>
            </div>

            <SmartLeadWorkbench
              leads={topPriorityLeads}
              activeFilter={filter}
              sort={leadSort}
              totalNeedsAction={queueCounts['Needs Action']}
              onFilter={setLeadFilter}
              onFocusLead={focusLead}
            />

            <div className="grid gap-3 lg:grid-cols-2">
              {displayedLeads.map((lead) => (
                <LeadCard
                  key={lead.id}
                  lead={lead}
                  selected={lead.id === selectedLead.id}
                  onSelect={() => focusLead(lead.id)}
                  expanded={expandedLeadIds.has(lead.id)}
                  onToggleExpand={() => toggleLeadDetails(lead.id)}
                />
              ))}
            </div>
            {filteredLeads.length > displayedLeads.length && (
              <button
                type="button"
                onClick={() => setVisibleLeadCount((count) => count + 12)}
                className="mt-4 h-10 w-full rounded-md border border-white/10 bg-white/[0.035] text-sm font-semibold text-slate-100 transition hover:bg-white/[0.07]"
              >
                Load 12 more aliases
              </button>
            )}
          </section>

          <CommandPanel
            lead={selectedLead}
            notice={notice}
            followupAt={followupAt}
            proposalAt={proposalAt}
            proposalNotes={proposalNotes}
            onFollowupChange={setFollowupAt}
            onProposalAtChange={setProposalAt}
            onProposalNotesChange={setProposalNotes}
            onRunAction={runAction}
            onSetQuality={setQuality}
            onSetBookingStage={setBookingStage}
            onSetBrokerageStatus={setBrokerageStatus}
            onSetFollowup={setFollowup}
            onProposeVisit={proposeVisit}
            onRaiseIssue={raiseIssue}
          />
        </div>

        <section className="grid gap-5 xl:grid-cols-[1fr_1fr]">
          <FollowupTriagePanel rows={followupRows} />
          <VisitPipeline proposals={proposals} leads={leads} />
        </section>

        <LockLedger leads={leads} />

        <section className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
          <ProjectsPanel projects={projects} />
          <ActivityPanel activity={activity} />
        </section>
      </main>

      {isAddOpen && (
        <AddLeadModal
          form={leadForm}
          onChange={setLeadForm}
          onClose={() => setIsAddOpen(false)}
          onSubmit={handleAddLead}
        />
      )}

      {isVisitSummaryOpen && (
        <VerifiedVisitsModal
          leads={verifiedVisitLeads}
          onClose={() => setIsVisitSummaryOpen(false)}
        />
      )}
    </div>
  );
}

function ScaleAllocationEngine({
  operations,
  leadSearch,
  projectFilter,
  leadSort,
  projectOptions,
  workforce,
  projects,
  onLeadSearchChange,
  onProjectFilterChange,
  onLeadSortChange,
  onAttachSms,
  onAttachDevelopers,
  onRouteBatch,
}: {
  operations: ReturnType<typeof buildOperationsSnapshot>;
  leadSearch: string;
  projectFilter: string;
  leadSort: LeadSort;
  projectOptions: string[];
  workforce: WorkforceMember[];
  projects: ProjectRow[];
  onLeadSearchChange: (value: string) => void;
  onProjectFilterChange: (value: string) => void;
  onLeadSortChange: (value: string) => void;
  onAttachSms: () => void;
  onAttachDevelopers: () => void;
  onRouteBatch: () => void;
}) {
  return (
    <section className="rounded-lg border border-white/10 bg-[#0b171b] p-4">
      <div className="grid gap-4 xl:grid-cols-[0.9fr_1.1fr]">
        <div>
          <SectionHeader
            icon={<Layers3 size={18} />}
            title="Scale Allocation Engine"
            subtitle="1000+ broker leads stay in the broker vault while work is routed through governed alias queues."
          />

          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <MiniMetric label="Vault leads" value={operations.totalLeads} />
            <MiniMetric label="Unassigned" value={operations.unassignedLeads} />
            <MiniMetric label="Batch ready" value={operations.batchReady} />
            <MiniMetric label="Capacity" value={operations.availableCapacity} />
          </div>

          <div className="mt-4 grid gap-2 lg:grid-cols-[1fr_220px_190px]">
            <Input label="Find lead instantly" value={leadSearch} onChange={onLeadSearchChange} placeholder="Alias, project, area, assignee" />
            <SelectInput label="Project route" value={projectFilter} options={projectOptions} onChange={onProjectFilterChange} />
            <SelectInput label="Sort leads by" value={leadSort} options={['Smart Priority', 'Follow-up First', 'Newest Updated', 'Most Calls', 'Alias A-Z']} onChange={onLeadSortChange} />
          </div>

          <div className="mt-4 grid gap-2 sm:grid-cols-3">
            <ActionButton icon={<UserCheck size={16} />} label="Attach 5 SMs" onClick={onAttachSms} />
            <ActionButton icon={<BriefcaseBusiness size={16} />} label="Attach 5 Developers" onClick={onAttachDevelopers} />
            <ActionButton icon={<Route size={16} />} label="Route 50 Leads" onClick={onRouteBatch} primary />
          </div>
        </div>

        <div className="grid gap-3 lg:grid-cols-2">
          <div className="rounded-lg border border-white/10 bg-white/[0.035] p-3">
            <div className="flex items-center justify-between gap-3">
              <p className="text-sm font-semibold text-white">Broker Team Routing</p>
              <StatusPill label={`${workforce.length} attached`} />
            </div>
            <div className="mt-3 space-y-2">
              {workforce.slice(0, 7).map((member) => (
                <div key={member.id} className="rounded-md border border-white/10 bg-black/20 p-3">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-sm font-semibold text-white">{member.name}</p>
                    <StatusPill label={member.role} compact />
                  </div>
                  <div className="mt-2 grid grid-cols-3 gap-2">
                    <Field label="Zone" value={member.zone} />
                    <Field label="Load" value={`${member.activeLoad}/${member.capacity}`} />
                    <Field label="Status" value={member.status} />
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="rounded-lg border border-white/10 bg-white/[0.035] p-3">
            <div className="flex items-center justify-between gap-3">
              <p className="text-sm font-semibold text-white">Developer Routes</p>
              <StatusPill label={`${projects.length} projects`} />
            </div>
            <div className="mt-3 space-y-2">
              {projects.slice(0, 7).map((project) => (
                <div key={project.id} className="rounded-md border border-white/10 bg-black/20 p-3">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-sm font-semibold text-white">{project.name}</p>
                    <StatusPill label={project.stage} compact />
                  </div>
                  <p className="mt-1 text-xs text-slate-500">{project.developer} · {project.area}</p>
                  <div className="mt-2 grid grid-cols-2 gap-2">
                    <Field label="Capacity" value={project.capacity} />
                    <Field label="Manager" value={project.manager} />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function SmartLeadWorkbench({
  leads,
  activeFilter,
  sort,
  totalNeedsAction,
  onFilter,
  onFocusLead,
}: {
  leads: BrokerLead[];
  activeFilter: LeadFilter;
  sort: LeadSort;
  totalNeedsAction: number;
  onFilter: (filter: LeadFilter) => void;
  onFocusLead: (leadId: string) => void;
}) {
  return (
    <div className="mb-4 rounded-lg border border-sky-300/15 bg-sky-300/[0.055] p-4">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <p className="text-sm font-semibold text-sky-100">Smart lead queue</p>
          <p className="mt-1 text-sm leading-6 text-slate-400">
            {totalNeedsAction} lead(s) need action. Current view: {activeFilter}. Sort: {sort}.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => onFilter('Needs Action')}
            className="h-9 rounded-md bg-sky-300 px-3 text-xs font-black uppercase tracking-wide text-slate-950 transition hover:bg-sky-200"
          >
            Work action queue
          </button>
          <button
            type="button"
            onClick={() => onFilter('Expired Access')}
            className="h-9 rounded-md border border-red-300/25 bg-red-300/10 px-3 text-xs font-black uppercase tracking-wide text-red-100 transition hover:bg-red-300/15"
          >
            Renew access first
          </button>
        </div>
      </div>

      <div className="mt-3 grid gap-2 md:grid-cols-3">
        {leads.length === 0 ? (
          <div className="rounded-md border border-white/10 bg-black/20 p-3 text-sm text-slate-400 md:col-span-3">
            No urgent lead needs action right now.
          </div>
        ) : (
          leads.map((lead, index) => (
            <button
              key={lead.id}
              type="button"
              onClick={() => onFocusLead(lead.id)}
              className="rounded-md border border-white/10 bg-black/20 p-3 text-left transition hover:border-sky-300/40 hover:bg-sky-300/10 focus:outline-none focus:ring-2 focus:ring-sky-200"
            >
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs font-black uppercase tracking-wide text-sky-200">#{index + 1} next</span>
                <StatusPill label={lead.leadQuality} compact />
              </div>
              <p className="mt-2 font-semibold text-white">{lead.alias} · {lead.area}</p>
              <p className="mt-1 text-xs leading-5 text-slate-400">{priorityReason(lead)}</p>
            </button>
          ))
        )}
      </div>
    </div>
  );
}

function LeadCard({
  lead,
  selected,
  expanded,
  onSelect,
  onToggleExpand,
}: {
  lead: BrokerLead;
  selected: boolean;
  expanded: boolean;
  onSelect: () => void;
  onToggleExpand: () => void;
}) {
  return (
    <article
      data-testid={`lead-card-${lead.alias}`}
      onClick={onSelect}
      role="button"
      tabIndex={0}
      onKeyDown={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          onSelect();
        }
      }}
      className={`min-h-[270px] rounded-lg border p-4 text-left transition focus:outline-none focus:ring-2 focus:ring-amber-200 ${
        selected
          ? 'border-amber-300/60 bg-amber-300/10'
          : 'border-white/10 bg-white/[0.035] hover:border-white/20 hover:bg-white/[0.055]'
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-lg font-semibold text-white">{lead.alias}</h3>
            <StatusPill label={lead.leadQuality} />
            <StatusPill label={lead.dataQuality} compact />
          </div>
          <p className="mt-1 text-sm text-slate-400">{lead.project} · {lead.area}</p>
        </div>
        <ChevronRight className="mt-1 text-slate-500" size={18} />
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        <LabeledStatus label="Call" value={lead.callStatus} />
        <LabeledStatus label="Visit" value={lead.visitStatus} />
        <LabeledStatus label="Lock" value={lead.brokerLock} />
      </div>

      <div className="mt-4 rounded-md border border-white/10 bg-black/20 p-3">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-500">Next action</p>
        <p className="mt-1 text-sm text-amber-100">{lead.nextAction}</p>
      </div>

      {expanded && (
        <div className="mt-4 grid grid-cols-2 gap-2">
          <Field label="Budget" value={lead.budget} />
          <Field label="Buyer" value={lead.buyerType} />
          <Field label="Assigned" value={lead.assignedTo} />
          <Field label="Calls" value={lead.callsAttempted} />
          <Field label="Call Permission" value={lead.dataLoan} />
          <Field label="Follow-up" value={lead.followupAt ? formatDate(lead.followupAt) : 'Not set'} />
          <Field label="Booking" value={lead.bookingStage} />
          <Field label="Brokerage" value={lead.brokerageStatus} />
        </div>
      )}

      <button
        type="button"
        onClick={(event) => {
          event.stopPropagation();
          onToggleExpand();
        }}
        className="mt-4 inline-flex h-9 items-center gap-2 rounded-md border border-white/10 bg-white/[0.035] px-3 text-sm font-semibold text-slate-100 transition hover:bg-white/[0.07]"
      >
        {expanded ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
        {expanded ? 'Hide details' : 'View details'}
      </button>
    </article>
  );
}

function LabeledStatus({ label, value }: { label: string; value: string }) {
  return (
    <span className="inline-flex items-center gap-1 rounded-full border border-white/10 bg-black/20 px-2 py-1 text-xs font-semibold text-slate-200">
      <span className="text-slate-500">{label}</span>
      <StatusPill label={value} compact />
    </span>
  );
}

function CommandPanel(props: {
  lead: BrokerLead;
  notice: string;
  followupAt: string;
  proposalAt: string;
  proposalNotes: string;
  onFollowupChange: (value: string) => void;
  onProposalAtChange: (value: string) => void;
  onProposalNotesChange: (value: string) => void;
  onRunAction: (action: string) => void;
  onSetQuality: (quality: LeadQuality) => void;
  onSetBookingStage: (stage: BookingStage) => void;
  onSetBrokerageStatus: (status: BrokerageStatus) => void;
  onSetFollowup: () => void;
  onProposeVisit: () => void;
  onRaiseIssue: () => void;
}) {
  const { lead } = props;

  return (
    <aside className="min-w-0 rounded-lg border border-white/10 bg-[#0b171b] p-4 xl:sticky xl:top-4 xl:self-start">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Selected lead</p>
          <h2 className="mt-1 text-xl font-semibold text-white">{lead.alias}</h2>
          <p className="mt-1 text-sm text-slate-400">{lead.project} · {lead.area}</p>
        </div>
        <StatusPill label={lead.leadQuality} />
      </div>

      <div className="mt-4 rounded-md border border-emerald-300/20 bg-emerald-300/10 p-3 text-sm leading-6 text-emerald-50/85">
        {props.notice}
      </div>

      <div className="mt-5 space-y-4">
        <PanelBlock title="Call & Access" icon={<PhoneCall size={16} />}>
          <div className="grid grid-cols-2 gap-2">
            <ActionButton icon={<PhoneCall size={16} />} label="Secure Call" onClick={() => props.onRunAction('secure_call')} primary />
            <ActionButton icon={<Users size={16} />} label="Assign Caller" onClick={() => props.onRunAction('grant_access')} />
            <ActionButton icon={<KeyRound size={16} />} label="Grant 24h" onClick={() => props.onRunAction('grant_access')} />
            <ActionButton icon={<RotateCw size={16} />} label="Extend" onClick={() => props.onRunAction('extend_access')} />
            <ActionButton icon={<X size={16} />} label="Revoke" onClick={() => props.onRunAction('revoke_access')} danger />
          </div>
        </PanelBlock>

        <PanelBlock title="Lifecycle Flow" icon={<Layers3 size={16} />}>
          <div className="grid grid-cols-3 gap-2 text-center text-xs">
            {[
              ['Loan', lead.dataLoan],
              ['Call', lead.callStatus],
              ['Visit', lead.visitStatus],
              ['Lock', lead.brokerLock],
              ['Booking', lead.bookingStage],
              ['Brokerage', lead.brokerageStatus],
            ].map(([label, value]) => (
              <div key={label} className="rounded-md border border-white/10 bg-white/[0.035] p-2">
                <p className="text-slate-500">{label}</p>
                <p className="mt-1 min-h-8 font-semibold text-slate-100">{value}</p>
              </div>
            ))}
          </div>
        </PanelBlock>

        <PanelBlock title="Visit & Follow-Up" icon={<CalendarClock size={16} />}>
          <div className="grid gap-2 sm:grid-cols-[1fr_auto]">
            <input
              type="datetime-local"
              value={props.followupAt}
              onChange={(event) => props.onFollowupChange(event.target.value)}
              className="h-10 rounded-md border border-white/10 bg-black/30 px-3 text-sm text-white outline-none focus:border-amber-300"
            />
            <button
              type="button"
              onClick={props.onSetFollowup}
              className="h-10 rounded-md bg-white px-3 text-sm font-semibold text-slate-950"
            >
              Set
            </button>
          </div>
          <div className="mt-3 space-y-2">
            <input
              type="datetime-local"
              value={props.proposalAt}
              onChange={(event) => props.onProposalAtChange(event.target.value)}
              className="h-10 w-full rounded-md border border-white/10 bg-black/30 px-3 text-sm text-white outline-none focus:border-amber-300"
            />
            <textarea
              value={props.proposalNotes}
              onChange={(event) => props.onProposalNotesChange(event.target.value)}
              rows={2}
              placeholder="Safe notes only"
              className="w-full resize-none rounded-md border border-white/10 bg-black/30 px-3 py-2 text-sm text-white outline-none focus:border-amber-300"
            />
            <button
              type="button"
              onClick={props.onProposeVisit}
              className="inline-flex h-10 w-full items-center justify-center gap-2 rounded-md bg-amber-400 px-3 text-sm font-semibold text-slate-950"
            >
              <ClipboardCheck size={16} />
              Propose Site Visit
            </button>
            <button
              type="button"
              onClick={() => props.onRunAction('verify_visit')}
              className="inline-flex h-10 w-full items-center justify-center gap-2 rounded-md border border-emerald-300/30 bg-emerald-300/10 px-3 text-sm font-semibold text-emerald-100"
            >
              <CheckCircle2 size={16} />
              Verify Visit + Create Lock
            </button>
          </div>
        </PanelBlock>

        <PanelBlock title="Pipeline & Status" icon={<Target size={16} />}>
          <div className="grid gap-2">
            <ActionButton icon={<UserCheck size={16} />} label="Assign SM" onClick={() => props.onRunAction('assign_sm')} />
            <SelectControl label="Quality" value={lead.leadQuality} options={['Hot', 'Warm', 'Cold']} onChange={(value) => props.onSetQuality(value as LeadQuality)} />
            <SelectControl
              label="Booking"
              value={lead.bookingStage}
              options={['Not Started', 'Booking Discussion', 'Token Discussion', 'Token Paid', 'Booking Confirmed', 'Lost']}
              onChange={(value) => props.onSetBookingStage(value as BookingStage)}
            />
            <SelectControl
              label="Brokerage"
              value={lead.brokerageStatus}
              options={['Tracking', 'Pending Visit', 'Locked', 'Eligible', 'Paid', 'Disputed', 'Blocked']}
              onChange={(value) => props.onSetBrokerageStatus(value as BrokerageStatus)}
            />
            <button
              type="button"
              onClick={props.onRaiseIssue}
              className="inline-flex h-10 items-center justify-center gap-2 rounded-md border border-red-300/30 bg-red-300/10 px-3 text-sm font-semibold text-red-100"
            >
              <MessageSquareWarning size={16} />
              Raise Issue
            </button>
          </div>
        </PanelBlock>
      </div>
    </aside>
  );
}

function AddLeadModal({
  form,
  onChange,
  onClose,
  onSubmit,
}: {
  form: AddLeadForm;
  onChange: (form: AddLeadForm) => void;
  onClose: () => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
}) {
  const update = (field: keyof AddLeadForm, value: string) => onChange({ ...form, [field]: value });

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 p-3 backdrop-blur-sm sm:items-center">
      <form onSubmit={onSubmit} className="w-full max-w-2xl rounded-lg border border-white/10 bg-[#0b171b] p-4 shadow-2xl">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold text-white">Secure Lead Intake</h2>
            <p className="mt-1 text-sm text-slate-400">One-time contact entry. Dashboard output stores alias and metadata only.</p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close secure lead intake" className="rounded-md p-2 text-slate-400 hover:bg-white/10 hover:text-white">
            <X size={18} />
          </button>
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          <Input label="Lead alias" value={form.alias} onChange={(value) => update('alias', value)} placeholder="L-1201" required />
          <Input label="One-time phone" value={form.oneTimePhone} onChange={(value) => update('oneTimePhone', value)} placeholder="Encrypted after submit" type="password" required />
          <Input label="Area" value={form.area} onChange={(value) => update('area', value)} placeholder="Mira Road" required />
          <Input label="City" value={form.city} onChange={(value) => update('city', value)} placeholder="Mumbai" required />
          <SelectInput label="Project" value={form.project} options={['Wadhwa Wise City', 'Lodha Amara', 'Godrej City']} onChange={(value) => update('project', value)} />
          <SelectInput label="Buyer type" value={form.buyerType} options={['End User', 'Investor', 'Family Decision']} onChange={(value) => update('buyerType', value)} />
          <Input label="Budget min" value={form.budgetMin} onChange={(value) => update('budgetMin', value)} placeholder="8000000" type="number" />
          <Input label="Budget max" value={form.budgetMax} onChange={(value) => update('budgetMax', value)} placeholder="10000000" type="number" />
        </div>

        <div className="mt-4 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <button type="button" onClick={onClose} className="h-10 rounded-md border border-white/10 px-4 text-sm font-semibold text-slate-200">
            Cancel
          </button>
          <button type="submit" className="inline-flex h-10 items-center justify-center gap-2 rounded-md bg-amber-400 px-4 text-sm font-semibold text-slate-950">
            <LockKeyhole size={16} />
            Encrypt and Secure
          </button>
        </div>
      </form>
    </div>
  );
}

function VerifiedVisitsModal({ leads, onClose }: { leads: BrokerLead[]; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 p-3 backdrop-blur-sm sm:items-center">
      <div className="w-full max-w-lg rounded-lg border border-white/10 bg-[#0b171b] p-4 shadow-2xl">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold text-white">Verified Visits</h2>
            <p className="mt-1 text-sm text-slate-400">
              {leads.length} verified visit(s) currently support broker attribution.
            </p>
          </div>
          <button type="button" onClick={onClose} aria-label="Close verified visits" className="rounded-md p-2 text-slate-400 hover:bg-white/10 hover:text-white">
            <X size={18} />
          </button>
        </div>
        <div className="mt-4 space-y-2">
          {leads.length === 0 ? (
            <div className="rounded-md border border-white/10 bg-white/[0.035] p-3 text-sm text-slate-400">No verified visits yet.</div>
          ) : (
            leads.slice(0, 8).map((lead) => (
              <div key={lead.id} className="rounded-md border border-emerald-300/20 bg-emerald-300/10 p-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p className="font-semibold text-white">{lead.alias} · {lead.project}</p>
                  <StatusPill label={lead.brokerLock} />
                </div>
                <p className="mt-1 text-sm text-emerald-50/75">Brokerage: {lead.brokerageStatus}</p>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

function VisitPipeline({ proposals, leads }: { proposals: VisitProposal[]; leads: BrokerLead[] }) {
  const visitLeads = leads.filter((lead) => lead.visitStatus !== 'Not Scheduled');
  return (
    <section>
      <SectionHeader icon={<Route size={18} />} title="Site Visit Proof Pipeline" subtitle="Proposal, GPS/photo proof, review, and lock outcome." />
      <div className="space-y-3">
        {proposals.slice(0, 3).map((proposal) => (
          <div key={proposal.id} className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <p className="font-semibold text-white">{proposal.leadAlias} · {proposal.project}</p>
              <StatusPill label={proposal.status} />
            </div>
            <p className="mt-2 text-sm text-slate-400">Proposed for {formatDate(proposal.proposedFor)}</p>
            <p className="mt-1 text-sm text-slate-500">{proposal.notes}</p>
          </div>
        ))}
        {visitLeads.map((lead) => (
          <div key={lead.id} className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <p className="font-semibold text-white">{lead.alias} · {lead.project}</p>
              <StatusPill label={lead.visitStatus} />
            </div>
            <div className="mt-3 grid grid-cols-4 gap-2 text-center text-xs text-slate-400">
              {['Proposed', 'GPS', 'Photo', 'Lock'].map((step) => (
                <div key={step} className={`rounded-md border p-2 ${stepDone(lead, step) ? 'border-emerald-300/25 bg-emerald-300/10 text-emerald-100' : 'border-white/10 bg-black/20'}`}>
                  {step}
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

function LockLedger({ leads }: { leads: BrokerLead[] }) {
  const lockRows = leads.filter((lead) => lead.brokerLock !== 'Not Started');
  return (
    <section>
      <SectionHeader icon={<LockKeyhole size={18} />} title="Broker Lock Ledger" subtitle="45-day attribution protection after verified visit." />
      <div className="space-y-3">
        {lockRows.map((lead) => (
          <div key={lead.id} className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <p className="font-semibold text-white">{lead.alias} · {lead.project}</p>
              <StatusPill label={lead.brokerLock} />
            </div>
            <div className="mt-3 grid grid-cols-2 gap-2">
              <Field label="Expiry" value={lead.lockExpiresAt ? formatDate(lead.lockExpiresAt) : 'Waiting proof'} />
              <Field label="Brokerage" value={lead.brokerageStatus} />
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

function ExpiredAccessPanel({ leads, onRenew }: { leads: BrokerLead[]; onRenew: (leadId: string) => void }) {
  return (
    <section className="rounded-lg border border-red-300/25 bg-red-300/10 p-4">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex items-start gap-3">
          <AlertTriangle className="mt-0.5 text-red-200" size={20} />
          <div>
            <p className="text-sm font-semibold text-red-100">Expired call access needs renewal</p>
            <p className="mt-1 text-sm leading-6 text-red-50/75">
              {leads.length} lead alias(es) are blocked for secure calling until access is renewed.
            </p>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          {leads.slice(0, 4).map((lead) => (
            <button
              key={lead.id}
              type="button"
              onClick={() => onRenew(lead.id)}
              className="inline-flex h-9 items-center gap-2 rounded-md bg-red-400 px-3 text-xs font-black uppercase tracking-wide text-white transition hover:bg-red-300"
            >
              <AlertTriangle size={14} />
              {lead.alias} · EXPIRED - RENEW
            </button>
          ))}
        </div>
      </div>
    </section>
  );
}

function FollowupTriagePanel({ rows }: { rows: BrokerLead[] }) {
  return (
    <section>
      <SectionHeader icon={<CalendarClock size={18} />} title="Follow-Up Triage" subtitle="Overdue, due-today, and upcoming broker tasks." />
      <div className="space-y-3">
        {rows.length === 0 ? (
          <div className="rounded-lg border border-white/10 bg-white/[0.035] p-4 text-sm text-slate-400">
            No due follow-ups right now.
          </div>
        ) : (
          rows.slice(0, 5).map((lead) => {
            const state = followupState(lead);
            const tone =
              state === 'OVERDUE'
                ? 'border-l-red-400'
                : state === 'TODAY'
                  ? 'border-l-amber-300'
                  : 'border-l-slate-500';
            return (
              <div key={lead.id} className={`rounded-lg border border-white/10 border-l-4 ${tone} bg-white/[0.035] p-4`}>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p className="font-semibold text-white">{lead.alias} · {lead.project}</p>
                  <StatusPill label={state} />
                </div>
                <p className="mt-2 text-sm text-slate-400">
                  Due: {lead.followupAt ? formatDate(lead.followupAt) : 'Not set'} · {lead.nextAction}
                </p>
              </div>
            );
          })
        )}
      </div>
    </section>
  );
}

function ProjectsPanel({ projects }: { projects: ProjectRow[] }) {
  return (
    <section>
      <SectionHeader icon={<BriefcaseBusiness size={18} />} title="Live Projects" subtitle="Connected projects and sourcing manager ownership." />
      <div className="space-y-3">
        {projects.map((project) => (
          <div key={project.id} className="rounded-lg border border-white/10 bg-white/[0.035] p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-semibold text-white">{project.name}</p>
                <p className="mt-1 text-sm text-slate-400">{project.developer} · {project.area} · {project.manager}</p>
              </div>
              <StatusPill label={project.stage} />
            </div>
            <div className="mt-3 grid grid-cols-2 gap-2">
              <Field label="Active leads" value={project.activeLeads} />
              <Field label="Capacity" value={project.capacity} />
              <Field label="Verified visits" value={project.verifiedVisits} />
              <Field label="Access" value="Proof gated" />
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

function ActivityPanel({ activity }: { activity: ActivityRow[] }) {
  return (
    <section>
      <SectionHeader icon={<ClipboardCheck size={18} />} title="Safe Activity Output" subtitle="Operational memory with aliases, states, and audit-safe event labels." />
      <div className="rounded-lg border border-white/10 bg-white/[0.035] p-2">
        {activity.slice(0, 8).map((row) => (
          <div key={row.id} className="flex gap-3 border-b border-white/10 p-3 last:border-b-0">
            <div className="mt-1 h-2.5 w-2.5 shrink-0 rounded-full bg-amber-300" />
            <div className="min-w-0">
              <p className="text-sm font-semibold text-white">
                {row.leadAlias ? `${row.leadAlias} · ` : ''}{humanize(row.kind)}
              </p>
              <p className="mt-1 text-sm leading-6 text-slate-400">{row.body}</p>
              <p className="mt-1 text-xs text-slate-600">{formatDate(row.at)}</p>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

function SectionHeader({ icon, title, subtitle }: { icon: React.ReactNode; title: string; subtitle: string }) {
  return (
    <div className="mb-3 flex items-start gap-2">
      <div className="mt-0.5 text-amber-200">{icon}</div>
      <div>
        <h2 className="text-base font-semibold text-white">{title}</h2>
        <p className="mt-1 text-sm text-slate-500">{subtitle}</p>
      </div>
    </div>
  );
}

function PanelBlock({ title, icon, children }: { title: string; icon: React.ReactNode; children: React.ReactNode }) {
  return (
    <div>
      <div className="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-200">
        <span className="text-slate-500">{icon}</span>
        {title}
      </div>
      {children}
    </div>
  );
}

function ActionButton({ icon, label, onClick, primary, danger }: { icon: React.ReactNode; label: string; onClick: () => void; primary?: boolean; danger?: boolean }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex h-10 items-center justify-center gap-2 rounded-md px-3 text-sm font-semibold transition ${
        primary
          ? 'bg-amber-400 text-slate-950 hover:bg-amber-300'
          : danger
            ? 'border border-red-300/25 bg-red-300/10 text-red-100 hover:bg-red-300/15'
            : 'border border-white/10 bg-white/[0.035] text-slate-100 hover:bg-white/[0.07]'
      }`}
    >
      {icon}
      {label}
    </button>
  );
}

function StatCard({
  icon,
  label,
  value,
  tone = 'slate',
  onClick,
}: {
  icon: React.ReactNode;
  label: string;
  value: number;
  tone?: string;
  onClick?: () => void;
}) {
  const colors = {
    slate: 'text-slate-300 bg-white/[0.035] border-white/10',
    orange: 'text-orange-200 bg-orange-300/10 border-orange-300/20',
    blue: 'text-sky-200 bg-sky-300/10 border-sky-300/20',
    amber: 'text-amber-200 bg-amber-300/10 border-amber-300/20',
    green: 'text-emerald-200 bg-emerald-300/10 border-emerald-300/20',
    purple: 'text-violet-200 bg-violet-300/10 border-violet-300/20',
  } as const;
  const className = colors[tone as keyof typeof colors] ?? colors.slate;
  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-lg border p-3 text-left transition hover:-translate-y-0.5 hover:bg-white/[0.07] focus:outline-none focus:ring-2 focus:ring-amber-200 ${className}`}
    >
      <div className="flex items-center justify-between gap-2">
        <span>{icon}</span>
        <span className="text-2xl font-semibold text-white">{value}</span>
      </div>
      <p className="mt-2 text-xs font-medium text-slate-400">{label}</p>
    </button>
  );
}

function MiniMetric({ label, value }: { label: string; value: number }) {
  return (
    <div className="min-w-20 rounded-md border border-white/10 bg-black/20 p-2">
      <p className="text-lg font-semibold text-white">{value}</p>
      <p className="mt-1 text-xs text-slate-500">{label}</p>
    </div>
  );
}

function Field({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="min-w-0 rounded-md bg-black/20 p-2">
      <p className="text-xs text-slate-500">{label}</p>
      <p className="mt-1 truncate text-sm font-medium text-slate-100">{value}</p>
    </div>
  );
}

function StatusPill({ label, compact }: { label: string; compact?: boolean }) {
  const tone = statusTone(label);
  return (
    <span className={`inline-flex items-center rounded-full border px-2 py-1 text-xs font-semibold ${compact ? 'text-[11px]' : ''} ${tone}`}>
      {label}
    </span>
  );
}

function TrustBadge({ icon, label, tone }: { icon: React.ReactNode; label: string; tone: 'green' | 'blue' | 'amber' }) {
  const colors = {
    green: 'border-emerald-300/20 bg-emerald-300/10 text-emerald-100',
    blue: 'border-sky-300/20 bg-sky-300/10 text-sky-100',
    amber: 'border-amber-300/20 bg-amber-300/10 text-amber-100',
  };
  return (
    <span className={`inline-flex h-10 items-center gap-2 rounded-md border px-3 text-sm font-semibold ${colors[tone]}`}>
      {icon}
      {label}
    </span>
  );
}

function SelectControl({ label, value, options, onChange }: { label: string; value: string; options: string[]; onChange: (value: string) => void }) {
  return (
    <label className="grid gap-1 text-xs text-slate-500">
      {label}
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="h-10 rounded-md border border-white/10 bg-black/30 px-3 text-sm text-white outline-none focus:border-amber-300"
      >
        {options.map((option) => (
          <option key={option} value={option}>{option}</option>
        ))}
      </select>
    </label>
  );
}

function Input({ label, value, onChange, placeholder, type = 'text', required }: { label: string; value: string; onChange: (value: string) => void; placeholder?: string; type?: string; required?: boolean }) {
  return (
    <label className="grid gap-1 text-xs font-medium text-slate-400">
      {label}
      <input
        type={type}
        value={value}
        required={required}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
        className="h-10 rounded-md border border-white/10 bg-black/30 px-3 text-sm text-white outline-none placeholder:text-slate-600 focus:border-amber-300"
      />
    </label>
  );
}

function SelectInput({ label, value, options, onChange }: { label: string; value: string; options: string[]; onChange: (value: string) => void }) {
  return (
    <label className="grid gap-1 text-xs font-medium text-slate-400">
      {label}
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="h-10 rounded-md border border-white/10 bg-black/30 px-3 text-sm text-white outline-none focus:border-amber-300"
      >
        {options.map((option) => (
          <option key={option} value={option}>{option}</option>
        ))}
      </select>
    </label>
  );
}

function buildScaleLeadVault(count: number): BrokerLead[] {
  const projects = ['Wadhwa Wise City', 'Lodha Amara'];
  const areas = ['Mira Road', 'Bhayandar', 'Thane', 'Panvel', 'Dombivli'];
  const buyerTypes: BrokerLead['buyerType'][] = ['End User', 'Investor', 'Family Decision'];
  const qualities: LeadQuality[] = ['Hot', 'Warm', 'Cold'];

  return Array.from({ length: count }, (_, index) => {
    const aliasNumber = 2000 + index;
    const leadQuality = qualities[index % qualities.length];
    const isCallerReady = index % 4 === 0;
    const isVisitReady = leadQuality === 'Hot' && index % 5 === 0;
    const isExpired = index % 9 === 0;
    const project = projects[index % projects.length];

    return {
      id: `lead-scale-${aliasNumber}`,
      alias: `L-${aliasNumber}`,
      project,
      area: areas[index % areas.length],
      city: 'Mumbai',
      budget: index % 2 === 0 ? 'Rs. 75L - Rs. 95L' : 'Rs. 95L - Rs. 1.25Cr',
      buyerType: buyerTypes[index % buyerTypes.length],
      assignedTo: isCallerReady ? 'Rahul Caller' : 'Unassigned',
      assignedRole: isCallerReady ? 'Caller' : 'Unassigned',
      dataLoan: isExpired ? 'Expired' : isCallerReady ? 'Active' : 'Inactive',
      loanExpiresAt: isExpired ? addHours(now, -2) : isCallerReady ? addHours(now, 10 + (index % 8)) : undefined,
      callStatus: isCallerReady ? 'Call Later' : 'Not Called',
      visitStatus: isVisitReady ? 'Proposed' : 'Not Scheduled',
      brokerLock: isVisitReady ? 'Pending' : 'Not Started',
      bookingStage: 'Not Started',
      brokerageStatus: isVisitReady ? 'Pending Visit' : 'Tracking',
      leadQuality,
      dataQuality: leadQuality === 'Hot' ? 'Strong' : leadQuality === 'Warm' ? 'Medium' : 'Weak',
      followupAt: index % 6 === 0 ? addHours(now, 2 + (index % 10)) : undefined,
      callsAttempted: isCallerReady ? 1 + (index % 2) : 0,
      nextAction: isVisitReady ? 'Wait for sourcing manager approval' : isCallerReady ? 'Secure call due' : 'Assign caller or sourcing manager',
      lastUpdated: addHours(now, -1 * (index % 72)),
    };
  });
}

function buildOperationsSnapshot(leads: BrokerLead[], workforce: WorkforceMember[], projects: ProjectRow[]) {
  const batchReady = leads.filter((lead) =>
    lead.brokerageStatus !== 'Blocked'
    && lead.brokerLock !== 'Active'
    && (lead.assignedRole === 'Unassigned' || lead.dataLoan === 'Expired' || lead.nextAction.includes('Assign')),
  ).length;

  return {
    totalLeads: leads.length,
    unassignedLeads: leads.filter((lead) => lead.assignedRole === 'Unassigned').length,
    batchReady,
    availableCapacity: workforce.reduce((sum, member) => sum + Math.max(0, member.capacity - member.activeLoad), 0),
    activeWorkers: workforce.filter((member) => member.status === 'Active').length,
    projectRoutes: projects.length,
    expiringLoans: leads.filter((lead) => lead.dataLoan === 'Expired').length,
  };
}

function buildLeadQueueCounts(leads: BrokerLead[]): Record<LeadFilter, number> {
  return {
    All: leads.length,
    'Needs Action': leads.filter(needsBrokerAction).length,
    'Expired Access': leads.filter((lead) => lead.dataLoan === 'Expired').length,
    Unassigned: leads.filter((lead) => lead.assignedRole === 'Unassigned').length,
    Hot: leads.filter((lead) => lead.leadQuality === 'Hot').length,
    Warm: leads.filter((lead) => lead.leadQuality === 'Warm').length,
    'Follow-up Due': leads.filter(isFollowupDue).length,
    'Visit Pending': leads.filter((lead) => lead.callStatus === 'Interested' && lead.visitStatus === 'Not Scheduled').length,
    Lock: leads.filter((lead) => lead.brokerLock === 'Active' || lead.brokerLock === 'Pending').length,
  };
}

function needsBrokerAction(lead: BrokerLead) {
  return (
    lead.dataLoan === 'Expired' ||
    lead.dataLoan === 'Revoked' ||
    lead.assignedRole === 'Unassigned' ||
    isFollowupDue(lead) ||
    (lead.leadQuality === 'Hot' && lead.visitStatus === 'Not Scheduled') ||
    lead.brokerLock === 'Pending' ||
    lead.brokerageStatus === 'Disputed' ||
    lead.bookingStage === 'Token Discussion'
  );
}

function sortLeads(leads: BrokerLead[], sort: LeadSort) {
  const rows = [...leads];
  switch (sort) {
    case 'Follow-up First':
      return rows.sort((a, b) => dateRank(a.followupAt) - dateRank(b.followupAt));
    case 'Newest Updated':
      return rows.sort((a, b) => dateRank(b.lastUpdated) - dateRank(a.lastUpdated));
    case 'Most Calls':
      return rows.sort((a, b) => b.callsAttempted - a.callsAttempted);
    case 'Alias A-Z':
      return rows.sort((a, b) => a.alias.localeCompare(b.alias, 'en-IN', { numeric: true }));
    case 'Smart Priority':
    default:
      return rows.sort((a, b) => smartPriorityScore(b) - smartPriorityScore(a));
  }
}

function smartPriorityScore(lead: BrokerLead) {
  let score = 0;
  if (!lead.id.startsWith('lead-scale-')) score += 240;
  if (lead.dataLoan === 'Expired') score += 120;
  if (lead.dataLoan === 'Revoked') score += 80;
  if (isFollowupDue(lead)) score += 95;
  if (lead.leadQuality === 'Hot') score += 70;
  if (lead.callStatus === 'Interested' && lead.visitStatus === 'Not Scheduled') score += 65;
  if (lead.assignedRole === 'Unassigned') score += 55;
  if (lead.brokerLock === 'Pending') score += 45;
  if (lead.bookingStage === 'Token Discussion') score += 40;
  if (lead.brokerageStatus === 'Disputed') score += 100;
  if (lead.callsAttempted === 0) score += 15;
  score -= Math.min(lead.callsAttempted, 8);
  return score;
}

function priorityReason(lead: BrokerLead) {
  if (lead.brokerageStatus === 'Disputed') return 'Brokerage dispute needs audit-safe resolution.';
  if (lead.dataLoan === 'Expired') return 'Call access expired. Renew before secure calling.';
  if (isFollowupDue(lead)) return 'Follow-up is due. Contact window should not slip.';
  if (lead.callStatus === 'Interested' && lead.visitStatus === 'Not Scheduled') return 'Interested lead has no site visit. Move to proposal.';
  if (lead.assignedRole === 'Unassigned') return 'No caller or sourcing manager assigned yet.';
  if (lead.brokerLock === 'Pending') return 'Broker lock is waiting on verified visit proof.';
  if (lead.leadQuality === 'Hot') return 'Hot lead should be worked before intent cools.';
  return lead.nextAction;
}

function dateRank(value?: string) {
  if (!value) return Number.MAX_SAFE_INTEGER;
  const timestamp = new Date(value).getTime();
  return Number.isNaN(timestamp) ? Number.MAX_SAFE_INTEGER : timestamp;
}

function pickLeastLoadedWorkforce(workforce: WorkforceMember[], leads: BrokerLead[], preferredZone?: string) {
  if (workforce.length === 0) return undefined;

  const loadByName = new Map<string, number>();
  leads.forEach((lead) => {
    if (lead.assignedRole !== 'Unassigned') {
      loadByName.set(lead.assignedTo, (loadByName.get(lead.assignedTo) ?? 0) + 1);
    }
  });

  return [...workforce].sort((a, b) => {
    const zoneScoreA = preferredZone && a.zone.toLowerCase() === preferredZone.toLowerCase() ? -100 : 0;
    const zoneScoreB = preferredZone && b.zone.toLowerCase() === preferredZone.toLowerCase() ? -100 : 0;
    const loadA = (loadByName.get(a.name) ?? a.activeLoad) / Math.max(1, a.capacity);
    const loadB = (loadByName.get(b.name) ?? b.activeLoad) / Math.max(1, b.capacity);
    return zoneScoreA + loadA - (zoneScoreB + loadB);
  })[0];
}

function buildStats(leads: BrokerLead[], proposals: VisitProposal[]) {
  return {
    totalLeads: leads.length,
    hotLeads: leads.filter((lead) => lead.leadQuality === 'Hot').length,
    callsAttempted: leads.reduce((sum, lead) => sum + lead.callsAttempted, 0),
    followupsDue: leads.filter(isFollowupDue).length,
    activeLoans: leads.filter((lead) => lead.dataLoan === 'Active').length,
    proposedVisits: proposals.length + leads.filter((lead) => lead.visitStatus === 'Proposed').length,
    verifiedVisits: leads.filter((lead) => lead.visitStatus === 'Verified').length,
    activeLocks: leads.filter((lead) => lead.brokerLock === 'Active').length,
    brokerageTracking: leads.filter((lead) => lead.brokerageStatus === 'Tracking' || lead.brokerageStatus === 'Locked').length,
  };
}

function buildFollowupRows(leads: BrokerLead[]) {
  return leads
    .filter((lead) => Boolean(lead.followupAt))
    .sort((a, b) => new Date(a.followupAt ?? '2999-01-01').getTime() - new Date(b.followupAt ?? '2999-01-01').getTime());
}

function isFollowupDue(lead: BrokerLead) {
  if (!lead.followupAt) return false;
  const due = new Date(lead.followupAt);
  const endOfToday = new Date(now);
  endOfToday.setHours(23, 59, 59, 999);
  return due.getTime() <= endOfToday.getTime();
}

function followupState(lead: BrokerLead) {
  if (!lead.followupAt) return 'UPCOMING';
  const due = new Date(lead.followupAt);
  const todayStart = new Date(now);
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date(now);
  todayEnd.setHours(23, 59, 59, 999);
  if (due.getTime() < todayStart.getTime()) return 'OVERDUE';
  if (due.getTime() <= todayEnd.getTime()) return 'TODAY';
  return 'UPCOMING';
}

function buildPriorityActions(leads: BrokerLead[]) {
  const expired = leads.filter((lead) => lead.dataLoan === 'Expired').length;
  const hotNoVisit = leads.filter((lead) => lead.leadQuality === 'Hot' && lead.visitStatus === 'Not Scheduled').length;
  const pendingLocks = leads.filter((lead) => lead.brokerLock === 'Pending').length;

  return [
    {
      title: expired > 0 ? 'Renew Access' : 'Access Healthy',
      body: expired > 0 ? `${expired} lead access window needs renewal before secure calling.` : 'No expired access window requires broker action.',
      icon: KeyRound,
      color: expired > 0 ? 'text-amber-200' : 'text-emerald-200',
    },
    {
      title: hotNoVisit > 0 ? 'Visit Pending' : 'Visit Flow Stable',
      body: hotNoVisit > 0 ? `${hotNoVisit} hot lead should move to proposal before intent cools.` : 'Hot leads are already in a visit or lock path.',
      icon: Route,
      color: hotNoVisit > 0 ? 'text-orange-200' : 'text-sky-200',
    },
    {
      title: pendingLocks > 0 ? 'Proof To Lock' : 'Locks Clear',
      body: pendingLocks > 0 ? `${pendingLocks} pending lock needs verified visit proof.` : 'No pending broker lock is waiting for proof.',
      icon: LockKeyhole,
      color: pendingLocks > 0 ? 'text-violet-200' : 'text-emerald-200',
    },
  ];
}

function statusTone(label: string) {
  const normalized = label.toLowerCase();
  if (['active', 'verified', 'eligible', 'paid', 'hot', 'strong', 'accepted', 'booking confirmed', 'locked'].includes(normalized)) {
    return 'border-emerald-300/20 bg-emerald-300/10 text-emerald-100';
  }
  if (['pending', 'proposed', 'scheduled', 'tracking', 'warm', 'medium', 'booking discussion', 'token discussion', 'pending visit', 'today', 'upcoming'].includes(normalized)) {
    return 'border-amber-300/20 bg-amber-300/10 text-amber-100';
  }
  if (['expired', 'revoked', 'blocked', 'lost', 'disputed', 'cold', 'weak', 'rejected', 'overdue'].includes(normalized)) {
    return 'border-red-300/20 bg-red-300/10 text-red-100';
  }
  return 'border-slate-300/15 bg-slate-300/10 text-slate-200';
}

function stepDone(lead: BrokerLead, step: string) {
  if (step === 'Proposed') return lead.visitStatus !== 'Not Scheduled';
  if (step === 'GPS') return lead.visitStatus === 'Proof Pending' || lead.visitStatus === 'Verified';
  if (step === 'Photo') return lead.visitStatus === 'Proof Pending' || lead.visitStatus === 'Verified';
  if (step === 'Lock') return lead.brokerLock === 'Active';
  return false;
}

function addHours(date: Date | number, hours: number) {
  const base = typeof date === 'number' ? new Date(date) : date;
  return new Date(base.getTime() + hours * 60 * 60 * 1000).toISOString();
}

function addDays(date: Date, days: number) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000).toISOString();
}

function formatDate(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Not set';
  return date.toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function humanize(value: string) {
  return value.replaceAll('_', ' ').replace(/\b\w/g, (match) => match.toUpperCase());
}

function scrubContactText(value: string) {
  return value.replace(/(\+?\d{1,4}[\s-]?)?\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{4}/g, '[contact removed]');
}

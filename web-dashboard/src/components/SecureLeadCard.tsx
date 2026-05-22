'use client';

import React from 'react';
import { motion } from 'framer-motion';
import { MoreVertical, Shield } from 'lucide-react';
import StatusPill from './StatusPill';

interface Lead {
  alias: string;
  project: string;
  area: string;
  budget: string;
  assignedTo: string;
  dataLoan: string;
  callStatus: string;
  visitStatus: string;
  brokerLock: string;
  bookingStage: string;
  brokerageStatus: string;
  leadQuality: string;
  nextAction: string;
}

interface SecureLeadCardProps {
  lead: Lead;
  onAction: (action: string, lead: Lead) => void;
}

const SecureLeadCard: React.FC<SecureLeadCardProps> = ({ lead, onAction }) => {
  const getPrimaryButton = () => {
    if (lead.dataLoan === 'Expired') return { text: 'Renew Call Access', action: 'renew' };
    if (lead.callStatus === 'Interested' && lead.visitStatus === 'Not Scheduled') return { text: 'Propose Site Visit', action: 'proposeVisit' };
    if (lead.visitStatus === 'Scheduled') return { text: 'View Visit Status', action: 'view' };
    return { text: 'Grant Call Access', action: 'grant' };
  };

  const primaryButton = getPrimaryButton();

  return (
    <motion.div
      data-testid={`lead-card-${lead.alias}`}
      className="bg-zinc-900/50 border border-white/5 rounded-xl p-4 mb-4 backdrop-blur-sm"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      whileHover={{ y: -2, borderColor: 'rgba(255,255,255,0.1)' }}
      transition={{ duration: 0.2 }}
    >
      {/* Top row */}
      <div className="flex justify-between items-start mb-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <h3 className="text-lg font-bold text-white">{lead.alias}</h3>
            <StatusPill status={lead.leadQuality} type="leadQuality" />
          </div>
          <p className="text-sm text-zinc-400">{lead.project} • {lead.area}</p>
        </div>
        <button
          className="p-2 rounded-lg hover:bg-white/5 transition-colors"
          aria-label={`Open actions for lead ${lead.alias}`}
          onClick={() => onAction('menu', lead)}
        >
          <MoreVertical className="w-5 h-5 text-zinc-400" />
        </button>
      </div>

      {/* Status pills */}
      <div className="flex flex-wrap gap-2 mb-4">
        <StatusPill status={lead.dataLoan} type="dataLoan" />
        <StatusPill status={lead.callStatus} type="callStatus" />
        <StatusPill status={lead.visitStatus} type="visitStatus" />
        <StatusPill status={lead.brokerLock} type="brokerLock" />
        <StatusPill status={lead.bookingStage} type="bookingStage" />
        <StatusPill status={lead.brokerageStatus} type="brokerageStatus" />
      </div>

      {/* Metadata */}
      <div className="space-y-2 mb-4 text-sm">
        <div className="flex justify-between">
          <span className="text-zinc-400">Budget:</span>
          <span className="text-white font-medium">{lead.budget}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-zinc-400">Assigned To:</span>
          <span className="text-white font-medium">{lead.assignedTo}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-zinc-400">Next Action:</span>
          <span className="text-orange-400 font-medium">{lead.nextAction}</span>
        </div>
      </div>

      {/* Buttons */}
      <div className="flex gap-3">
        <motion.button
          className="flex-1 bg-gradient-to-r from-orange-500 to-yellow-500 text-black font-semibold py-3 px-4 rounded-xl shadow-lg"
          aria-label={`${primaryButton.text} for lead ${lead.alias}`}
          whileTap={{ scale: 0.95 }}
          onClick={() => onAction(primaryButton.action, lead)}
        >
          {primaryButton.text}
        </motion.button>
        <motion.button
          className="w-12 bg-zinc-800 border border-white/10 rounded-xl flex items-center justify-center"
          aria-label={`Start secure call for lead ${lead.alias}`}
          whileTap={{ scale: 0.95 }}
          onClick={() => onAction('secureCall', lead)}
        >
          <Shield className="w-5 h-5 text-zinc-400" />
        </motion.button>
      </div>
    </motion.div>
  );
};

export default SecureLeadCard;

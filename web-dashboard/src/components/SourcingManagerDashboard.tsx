'use client';

import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { CheckCircle, XCircle, MapPin, Calendar, Eye } from 'lucide-react';

type DashboardTab = 'proposals' | 'scheduled' | 'performance';

interface VisitProposal {
  id: string;
  leadAlias: string;
  project: string;
  area: string;
  brokerName: string;
  proposedDate: string;
  proposedTime: string;
  notes: string;
  status: 'pending' | 'accepted' | 'rejected';
}

interface ScheduledVisit {
  id: string;
  leadAlias: string;
  project: string;
  area: string;
  brokerName: string;
  scheduledDate: string;
  scheduledTime: string;
  status: 'scheduled' | 'client_reached' | 'verified' | 'no_show';
}

const SourcingManagerDashboard: React.FC = () => {
  const [activeTab, setActiveTab] = useState<DashboardTab>('proposals');

  const mockProposals: VisitProposal[] = [
    {
      id: 'prop-1',
      leadAlias: 'L-1042',
      project: 'Wadhwa Wise City',
      area: 'Mira Road',
      brokerName: 'Jitu Gupta',
      proposedDate: '2026-05-15',
      proposedTime: '14:00',
      notes: 'Client interested in 3BHK, budget ₹1.2Cr',
      status: 'pending',
    },
    {
      id: 'prop-2',
      leadAlias: 'L-1088',
      project: 'Lodha Amara',
      area: 'Thane',
      brokerName: 'Rajesh Kumar',
      proposedDate: '2026-05-16',
      proposedTime: '11:00',
      notes: 'Follow-up visit for 2BHK inquiry',
      status: 'pending',
    },
  ];

  const mockScheduledVisits: ScheduledVisit[] = [
    {
      id: 'visit-1',
      leadAlias: 'L-1042',
      project: 'Wadhwa Wise City',
      area: 'Mira Road',
      brokerName: 'Jitu Gupta',
      scheduledDate: '2026-05-15',
      scheduledTime: '14:00',
      status: 'scheduled',
    },
    {
      id: 'visit-2',
      leadAlias: 'L-1120',
      project: 'Godrej City',
      area: 'Panvel',
      brokerName: 'Amit Singh',
      scheduledDate: '2026-05-14',
      scheduledTime: '16:00',
      status: 'client_reached',
    },
  ];

  const handleProposalAction = (proposalId: string, action: 'accept' | 'reject') => {
    window.dispatchEvent(new CustomEvent('visit-proposal-action', { detail: { proposalId, action } }));
  };

  const handleVisitAction = (visitId: string, action: string) => {
    window.dispatchEvent(new CustomEvent('site-visit-action', { detail: { visitId, action } }));
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      {/* Header */}
      <div className="sticky top-0 z-50 bg-zinc-950/80 backdrop-blur-md border-b border-white/5 px-4 py-4">
        <div className="max-w-md mx-auto">
          <h1 className="text-xl font-bold text-white text-center">Sourcing Manager Dashboard</h1>
          <p className="text-sm text-zinc-400 text-center">JSN Enterprise • Mira Road</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex bg-zinc-900/50 mx-4 mt-4 rounded-xl p-1">
        {([
          { id: 'proposals', label: 'Proposals', count: mockProposals.filter(p => p.status === 'pending').length },
          { id: 'scheduled', label: 'Scheduled', count: mockScheduledVisits.filter(v => v.status === 'scheduled').length },
          { id: 'performance', label: 'Performance' },
        ] satisfies Array<{ id: DashboardTab; label: string; count?: number }>).map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex-1 py-3 px-4 rounded-lg text-sm font-medium transition-colors ${
              activeTab === tab.id
                ? 'bg-orange-500 text-black'
                : 'text-zinc-400 hover:text-white'
            }`}
          >
            {tab.label}
            {tab.count !== undefined && tab.count > 0 && (
              <span className="ml-1 bg-red-500 text-white text-xs px-1.5 py-0.5 rounded-full">
                {tab.count}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="p-4 space-y-4">
        {activeTab === 'proposals' && (
          <div className="space-y-4">
            <h2 className="text-lg font-bold text-white">Visit Proposals</h2>
            {mockProposals.map((proposal) => (
              <motion.div
                key={proposal.id}
                className="bg-zinc-900/50 border border-white/5 rounded-xl p-4"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
              >
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <h3 className="text-lg font-bold text-white">{proposal.leadAlias}</h3>
                    <p className="text-sm text-zinc-400">{proposal.project} • {proposal.area}</p>
                    <p className="text-sm text-zinc-400">Broker: {proposal.brokerName}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm text-orange-400">{proposal.proposedDate}</p>
                    <p className="text-sm text-zinc-400">{proposal.proposedTime}</p>
                  </div>
                </div>

                {proposal.notes && (
                  <p className="text-sm text-zinc-300 mb-4">{proposal.notes}</p>
                )}

                <div className="flex gap-3">
                  <motion.button
                    className="flex-1 bg-green-600 text-white font-semibold py-3 px-4 rounded-xl"
                    whileTap={{ scale: 0.95 }}
                    onClick={() => handleProposalAction(proposal.id, 'accept')}
                  >
                    <div className="flex items-center justify-center gap-2">
                      <CheckCircle className="w-5 h-5" />
                      Accept
                    </div>
                  </motion.button>
                  <motion.button
                    className="flex-1 bg-red-600 text-white font-semibold py-3 px-4 rounded-xl"
                    whileTap={{ scale: 0.95 }}
                    onClick={() => handleProposalAction(proposal.id, 'reject')}
                  >
                    <div className="flex items-center justify-center gap-2">
                      <XCircle className="w-5 h-5" />
                      Reject
                    </div>
                  </motion.button>
                </div>
              </motion.div>
            ))}
          </div>
        )}

        {activeTab === 'scheduled' && (
          <div className="space-y-4">
            <h2 className="text-lg font-bold text-white">Scheduled Visits</h2>
            {mockScheduledVisits.map((visit) => (
              <motion.div
                key={visit.id}
                className="bg-zinc-900/50 border border-white/5 rounded-xl p-4"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
              >
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <h3 className="text-lg font-bold text-white">{visit.leadAlias}</h3>
                    <p className="text-sm text-zinc-400">{visit.project} • {visit.area}</p>
                    <p className="text-sm text-zinc-400">Broker: {visit.brokerName}</p>
                  </div>
                  <div className={`px-3 py-1 rounded-full text-xs font-medium ${
                    visit.status === 'scheduled' ? 'bg-blue-500/10 text-blue-400 border border-blue-500/20' :
                    visit.status === 'client_reached' ? 'bg-green-500/10 text-green-400 border border-green-500/20' :
                    'bg-gray-500/10 text-gray-400 border border-gray-500/20'
                  }`}>
                    {visit.status === 'scheduled' ? 'Scheduled' :
                     visit.status === 'client_reached' ? 'Client Reached' :
                     'Verified'}
                  </div>
                </div>

                <div className="flex items-center gap-2 mb-4">
                  <Calendar className="w-4 h-4 text-zinc-400" />
                  <span className="text-sm text-zinc-300">{visit.scheduledDate} at {visit.scheduledTime}</span>
                </div>

                <div className="flex gap-3">
                  <motion.button
                    className="flex-1 bg-blue-600 text-white font-semibold py-3 px-4 rounded-xl"
                    whileTap={{ scale: 0.95 }}
                    onClick={() => handleVisitAction(visit.id, 'view')}
                  >
                    <div className="flex items-center justify-center gap-2">
                      <Eye className="w-5 h-5" />
                      View Details
                    </div>
                  </motion.button>
                  {visit.status === 'scheduled' && (
                    <motion.button
                      className="flex-1 bg-orange-600 text-white font-semibold py-3 px-4 rounded-xl"
                      whileTap={{ scale: 0.95 }}
                      onClick={() => handleVisitAction(visit.id, 'confirm_arrival')}
                    >
                      <div className="flex items-center justify-center gap-2">
                        <MapPin className="w-5 h-5" />
                        Confirm Arrival
                      </div>
                    </motion.button>
                  )}
                </div>
              </motion.div>
            ))}
          </div>
        )}

        {activeTab === 'performance' && (
          <div className="space-y-4">
            <h2 className="text-lg font-bold text-white">Broker Performance</h2>
            <div className="bg-zinc-900/50 border border-white/5 rounded-xl p-4">
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-zinc-400">Jitu Gupta</span>
                  <span className="text-green-400 font-medium">85% Success Rate</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-400">Rajesh Kumar</span>
                  <span className="text-yellow-400 font-medium">72% Success Rate</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-zinc-400">Amit Singh</span>
                  <span className="text-green-400 font-medium">91% Success Rate</span>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default SourcingManagerDashboard;

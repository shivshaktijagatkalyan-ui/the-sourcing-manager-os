'use client';

import React, { useState } from 'react';
import { motion } from 'framer-motion';
import StickyTrustHeader from './StickyTrustHeader';
import KpiRibbon from './KpiRibbon';
import BrokerIdentityCard from './BrokerIdentityCard';
import GrowthInsightCard from './GrowthInsightCard';
import SecureLeadCard from './SecureLeadCard';
import LeadActionBottomSheet from './LeadActionBottomSheet';
import ProposeSiteVisitSheet from './ProposeSiteVisitSheet';

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

const mockLeads: Lead[] = [
  {
    alias: 'L-1042',
    project: 'Wadhwa Wise City',
    area: 'Mira Road',
    budget: '₹80L–₹1Cr',
    assignedTo: 'Rahul Caller',
    dataLoan: 'Active',
    callStatus: 'Interested',
    visitStatus: 'Scheduled',
    brokerLock: 'Pending',
    bookingStage: 'Not Started',
    brokerageStatus: 'Tracking',
    leadQuality: 'Hot',
    nextAction: 'Confirm Sunday site visit',
  },
  {
    alias: 'L-1088',
    project: 'Wadhwa Wise City',
    area: 'Bhayandar',
    budget: '₹65L–₹85L',
    assignedTo: 'Vinod SM',
    dataLoan: 'Expired',
    callStatus: 'Call Later',
    visitStatus: 'Not Scheduled',
    brokerLock: 'Not Started',
    bookingStage: 'Not Started',
    brokerageStatus: 'Tracking',
    leadQuality: 'Warm',
    nextAction: 'Renew call access',
  },
  {
    alias: 'L-1120',
    project: 'Wadhwa Wise City',
    area: 'Mira Road',
    budget: '₹1Cr–₹1.25Cr',
    assignedTo: 'Rahul Caller',
    dataLoan: 'Revoked',
    callStatus: 'Not Reachable',
    visitStatus: 'Not Scheduled',
    brokerLock: 'Blocked',
    bookingStage: 'Lost',
    brokerageStatus: 'Blocked',
    leadQuality: 'Cold',
    nextAction: 'Review lead quality',
  },
];

const BrokerDashboardFutureTrust: React.FC = () => {
  const [selectedLead, setSelectedLead] = useState<Lead | null>(null);
  const [isBottomSheetOpen, setIsBottomSheetOpen] = useState(false);
  const [isProposeSheetOpen, setIsProposeSheetOpen] = useState(false);

  const mockProjects = [
    { id: 'proj-1', name: 'Wadhwa Wise City', area: 'Panvel' },
    { id: 'proj-2', name: 'Lodha Amara', area: 'Thane' },
    { id: 'proj-3', name: 'Godrej City', area: 'Panvel' },
  ];

  const handleLeadAction = (action: string, lead: Lead) => {
    if (action === 'menu') {
      setSelectedLead(lead);
      setIsBottomSheetOpen(true);
    } else if (action === 'proposeVisit') {
      setSelectedLead(lead);
      setIsProposeSheetOpen(true);
    } else {
      // Handle other actions, e.g., show toast or navigate
      console.log(`Action: ${action} for lead ${lead.alias}`);
    }
  };

  const handlePropose = (projectId: string, date: string, time: string, notes: string) => {
    if (selectedLead) {
      console.log(`Proposing site visit for lead ${selectedLead.alias}:`, {
        projectId,
        date,
        time,
        notes,
      });
      // Here you would call the API to propose the site visit
    }
  };

  const handleBottomSheetAction = (action: string) => {
    if (selectedLead) {
      console.log(`Bottom sheet action: ${action} for lead ${selectedLead.alias}`);
    }
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <StickyTrustHeader />

      <div className="pb-8">
        <KpiRibbon />

        <BrokerIdentityCard />

        <GrowthInsightCard />

        {/* Lead Pipeline Summary - placeholder */}
        <div className="mx-4 mb-6">
          <h2 className="text-lg font-bold text-white mb-4">Secure Lead Feed</h2>
          <div className="space-y-4">
            {mockLeads.map((lead, index) => (
              <motion.div
                key={lead.alias}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.1 }}
              >
                <SecureLeadCard lead={lead} onAction={handleLeadAction} />
              </motion.div>
            ))}
          </div>
        </div>

        {/* Other sections can be added here */}
      </div>

      <LeadActionBottomSheet
        isOpen={isBottomSheetOpen}
        onClose={() => setIsBottomSheetOpen(false)}
        leadAlias={selectedLead?.alias || ''}
        onAction={handleBottomSheetAction}
      />

      <ProposeSiteVisitSheet
        isOpen={isProposeSheetOpen}
        onClose={() => setIsProposeSheetOpen(false)}
        leadAlias={selectedLead?.alias || ''}
        projects={mockProjects}
        onPropose={handlePropose}
      />
    </div>
  );
};

export default BrokerDashboardFutureTrust;
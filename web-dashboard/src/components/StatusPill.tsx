import React from 'react';

interface StatusPillProps {
  status: string;
  type: 'dataLoan' | 'callStatus' | 'visitStatus' | 'brokerLock' | 'bookingStage' | 'brokerageStatus' | 'leadQuality';
}

const statusColors: Record<string, { bg: string; text: string; border: string }> = {
  // Green
  Verified: { bg: 'bg-green-500/10', text: 'text-green-400', border: 'border-green-500/20' },
  Active: { bg: 'bg-green-500/10', text: 'text-green-400', border: 'border-green-500/20' },
  Interested: { bg: 'bg-green-500/10', text: 'text-green-400', border: 'border-green-500/20' },
  Completed: { bg: 'bg-green-500/10', text: 'text-green-400', border: 'border-green-500/20' },
  Paid: { bg: 'bg-green-500/10', text: 'text-green-400', border: 'border-green-500/20' },

  // Orange
  Pending: { bg: 'bg-orange-500/10', text: 'text-orange-400', border: 'border-orange-500/20' },
  'Call Later': { bg: 'bg-orange-500/10', text: 'text-orange-400', border: 'border-orange-500/20' },
  'Follow-up': { bg: 'bg-orange-500/10', text: 'text-orange-400', border: 'border-orange-500/20' },
  'Booking Discussion': { bg: 'bg-orange-500/10', text: 'text-orange-400', border: 'border-orange-500/20' },
  Tracking: { bg: 'bg-orange-500/10', text: 'text-orange-400', border: 'border-orange-500/20' },

  // Red
  Blocked: { bg: 'bg-red-500/10', text: 'text-red-400', border: 'border-red-500/20' },
  Revoked: { bg: 'bg-red-500/10', text: 'text-red-400', border: 'border-red-500/20' },
  Expired: { bg: 'bg-red-500/10', text: 'text-red-400', border: 'border-red-500/20' },
  Rejected: { bg: 'bg-red-500/10', text: 'text-red-400', border: 'border-red-500/20' },
  Lost: { bg: 'bg-red-500/10', text: 'text-red-400', border: 'border-red-500/20' },

  // Blue
  Scheduled: { bg: 'bg-blue-500/10', text: 'text-blue-400', border: 'border-blue-500/20' },
  Assigned: { bg: 'bg-blue-500/10', text: 'text-blue-400', border: 'border-blue-500/20' },
  'Visit Scheduled': { bg: 'bg-blue-500/10', text: 'text-blue-400', border: 'border-blue-500/20' },

  // Purple
  Hot: { bg: 'bg-purple-500/10', text: 'text-purple-400', border: 'border-purple-500/20' },
  'High Potential': { bg: 'bg-purple-500/10', text: 'text-purple-400', border: 'border-purple-500/20' },
  Premium: { bg: 'bg-purple-500/10', text: 'text-purple-400', border: 'border-purple-500/20' },

  // Grey
  Inactive: { bg: 'bg-gray-500/10', text: 'text-gray-400', border: 'border-gray-500/20' },
  'Not Started': { bg: 'bg-gray-500/10', text: 'text-gray-400', border: 'border-gray-500/20' },
  Cold: { bg: 'bg-gray-500/10', text: 'text-gray-400', border: 'border-gray-500/20' },
  'Not Scheduled': { bg: 'bg-gray-500/10', text: 'text-gray-400', border: 'border-gray-500/20' },
  'Not Reachable': { bg: 'bg-red-500/10', text: 'text-red-400', border: 'border-red-500/20' }, // Assuming red for not reachable
};

const StatusPill: React.FC<StatusPillProps> = ({ status }) => {
  const colors = statusColors[status] || { bg: 'bg-gray-500/10', text: 'text-gray-400', border: 'border-gray-500/20' };

  return (
    <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium border ${colors.bg} ${colors.text} ${colors.border}`}>
      {status}
    </span>
  );
};

export default StatusPill;
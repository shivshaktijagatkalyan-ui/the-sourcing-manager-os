'use client';

import React from 'react';
import { motion } from 'framer-motion';

interface KpiCardProps {
  title: string;
  value: string | number;
  change?: string;
  isHighlighted?: boolean;
}

const KpiCard: React.FC<KpiCardProps> = ({ title, value, change, isHighlighted }) => {
  return (
    <motion.div
      className={`bg-zinc-900/50 border rounded-xl p-4 min-w-[120px] flex-shrink-0 ${
        isHighlighted ? 'border-orange-500/30 shadow-lg shadow-orange-500/10' : 'border-white/5'
      }`}
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
    >
      <div className="text-2xl font-bold text-white mb-1">{value}</div>
      <div className="text-xs text-zinc-400 mb-1">{title}</div>
      {change && (
        <div className={`text-xs ${change.startsWith('+') ? 'text-green-400' : 'text-red-400'}`}>
          {change}
        </div>
      )}
    </motion.div>
  );
};

export default KpiCard;
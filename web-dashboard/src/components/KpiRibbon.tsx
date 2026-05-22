'use client';

import React from 'react';
import { motion } from 'framer-motion';
import KpiCard from './KpiCard';

const kpiData = [
  { title: 'Total Leads', value: 47, change: '+5' },
  { title: 'Hot Leads', value: 12, change: '+2' },
  { title: 'Calls Attempted', value: 89, change: '+12' },
  { title: 'Interested Leads', value: 23, change: '+3' },
  { title: 'Site Visits Scheduled', value: 8, change: '+1' },
  { title: 'Verified Visits', value: 15, change: '+4' },
  { title: 'Active 45-Day Locks', value: 6, isHighlighted: true },
  { title: 'Data Loans Active', value: 18 },
  { title: 'Booking Discussions', value: 3 },
  { title: 'Brokerage Tracking', value: 12 },
];

const KpiRibbon: React.FC = () => {
  return (
    <motion.div
      className="flex gap-3 overflow-x-auto pb-2 px-4"
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, delay: 0.2 }}
    >
      {kpiData.map((kpi) => (
        <KpiCard
          key={kpi.title}
          title={kpi.title}
          value={kpi.value}
          change={kpi.change}
          isHighlighted={kpi.isHighlighted}
        />
      ))}
    </motion.div>
  );
};

export default KpiRibbon;

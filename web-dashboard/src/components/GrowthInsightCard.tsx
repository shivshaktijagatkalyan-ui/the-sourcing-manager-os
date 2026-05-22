'use client';

import React from 'react';
import { motion } from 'framer-motion';
import { TrendingUp, MapPin, Star, Target } from 'lucide-react';

const GrowthInsightCard: React.FC = () => {
  return (
    <motion.div
      className="bg-zinc-900/50 border border-white/5 rounded-xl p-6 mx-4 mb-6"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, delay: 0.4 }}
    >
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 bg-gradient-to-br from-green-500 to-blue-500 rounded-full flex items-center justify-center">
          <TrendingUp className="w-5 h-5 text-white" />
        </div>
        <h3 className="text-lg font-bold text-white">Today&apos;s Smart Growth Tip</h3>
      </div>

      <p className="text-sm text-zinc-300 mb-4">
        Your Mira Road leads are converting better for Wadhwa Wise City. Send more ₹80L–₹1Cr budget buyers this week.
      </p>

      <div className="flex flex-wrap gap-2 mb-4">
        <div className="flex items-center gap-1 bg-green-500/10 text-green-400 px-3 py-1 rounded-full text-xs border border-green-500/20">
          <MapPin className="w-3 h-3" />
          Strongest Area: Mira Road
        </div>
        <div className="flex items-center gap-1 bg-blue-500/10 text-blue-400 px-3 py-1 rounded-full text-xs border border-blue-500/20">
          <Star className="w-3 h-3" />
          Best Project: Wadhwa Wise City
        </div>
        <div className="flex items-center gap-1 bg-purple-500/10 text-purple-400 px-3 py-1 rounded-full text-xs border border-purple-500/20">
          <Target className="w-3 h-3" />
          Lead Quality: Strong
        </div>
      </div>

      <motion.button
        className="w-full bg-zinc-800 border border-white/10 text-white font-medium py-3 px-4 rounded-xl hover:bg-zinc-700 transition-colors"
        whileTap={{ scale: 0.98 }}
      >
        View Growth Plan
      </motion.button>
    </motion.div>
  );
};

export default GrowthInsightCard;

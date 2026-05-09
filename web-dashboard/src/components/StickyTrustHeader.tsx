'use client';

import React from 'react';
import { motion } from 'framer-motion';
import { Shield, Star, Heart } from 'lucide-react';

const StickyTrustHeader: React.FC = () => {
  return (
    <motion.header
      className="sticky top-0 z-50 bg-zinc-950/80 backdrop-blur-md border-b border-white/5 px-4 py-4"
      initial={{ y: -24, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.5, ease: 'easeOut' }}
    >
      <div className="max-w-md mx-auto">
        <div className="text-center mb-3">
          <h1 className="text-xl font-bold text-white">Good Morning, Jitu</h1>
          <p className="text-sm text-zinc-400">JSN Enterprise • Mira Road</p>
        </div>

        <div className="flex justify-center gap-4 text-sm">
          <div className="flex items-center gap-1 bg-green-500/10 text-green-400 px-3 py-1 rounded-full border border-green-500/20">
            <Shield className="w-4 h-4" />
            Verified Active Broker
          </div>
          <div className="flex items-center gap-1 bg-blue-500/10 text-blue-400 px-3 py-1 rounded-full border border-blue-500/20">
            <Star className="w-4 h-4" />
            Rank #4
          </div>
          <div className="flex items-center gap-1 bg-purple-500/10 text-purple-400 px-3 py-1 rounded-full border border-purple-500/20">
            <Heart className="w-4 h-4" />
            98% Trust
          </div>
        </div>

        <div className="text-center mt-2">
          <p className="text-xs text-zinc-500">Data Protected</p>
        </div>
      </div>
    </motion.header>
  );
};

export default StickyTrustHeader;
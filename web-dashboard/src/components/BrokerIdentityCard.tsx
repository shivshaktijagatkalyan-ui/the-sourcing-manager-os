'use client';

import React from 'react';
import { motion } from 'framer-motion';
import { User, MapPin, Building, Star, Shield } from 'lucide-react';

const BrokerIdentityCard: React.FC = () => {
  return (
    <motion.div
      className="bg-zinc-900/50 border border-white/5 rounded-xl p-6 mx-4 mb-6"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, delay: 0.3 }}
    >
      <div className="flex items-center gap-4 mb-4">
        <div className="w-12 h-12 bg-gradient-to-br from-orange-500 to-yellow-500 rounded-full flex items-center justify-center">
          <User className="w-6 h-6 text-black" />
        </div>
        <div>
          <h3 className="text-lg font-bold text-white">BRK-JSN-0001</h3>
          <p className="text-sm text-zinc-400">Jitu Gupta</p>
        </div>
      </div>

      <div className="space-y-3">
        <div className="flex items-center gap-3">
          <Building className="w-5 h-5 text-zinc-400" />
          <div>
            <p className="text-sm font-medium text-white">JSN Enterprise</p>
            <p className="text-xs text-zinc-400">Company</p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <MapPin className="w-5 h-5 text-zinc-400" />
          <div>
            <p className="text-sm font-medium text-white">Mira Road</p>
            <p className="text-xs text-zinc-400">Area Strength</p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <Star className="w-5 h-5 text-zinc-400" />
          <div>
            <p className="text-sm font-medium text-white">Wadhwa Wise City, Panvel</p>
            <p className="text-xs text-zinc-400">Connected Project</p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <Shield className="w-5 h-5 text-zinc-400" />
          <div>
            <p className="text-sm font-medium text-white">Vinod Gupta</p>
            <p className="text-xs text-zinc-400">Connected Sourcing Manager</p>
          </div>
        </div>
      </div>

      <div className="mt-4 pt-4 border-t border-white/5">
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm text-zinc-400">Status</span>
          <span className="text-sm font-medium text-green-400">Verified Active Broker</span>
        </div>
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm text-zinc-400">Performance Rank</span>
          <span className="text-sm font-medium text-blue-400">Silver</span>
        </div>
        <div className="flex justify-between items-center">
          <span className="text-sm text-zinc-400">Trust Score</span>
          <span className="text-sm font-medium text-purple-400">98%</span>
        </div>
      </div>

      <div className="mt-4 p-3 bg-blue-500/10 border border-blue-500/20 rounded-lg">
        <p className="text-sm text-blue-400 text-center">
          Aapka broker credit system mein protected hai.
        </p>
      </div>
    </motion.div>
  );
};

export default BrokerIdentityCard;

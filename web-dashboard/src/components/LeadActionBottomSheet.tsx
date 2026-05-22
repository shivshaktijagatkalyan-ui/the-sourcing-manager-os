'use client';

import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Phone, User, Calendar, Shield, AlertTriangle, RotateCcw } from 'lucide-react';

interface LeadActionBottomSheetProps {
  isOpen: boolean;
  onClose: () => void;
  leadAlias: string;
  onAction: (action: string) => void;
}

const actions = [
  { icon: Phone, label: 'Secure Call', desc: 'Protected call bridge', action: 'secureCall' },
  { icon: User, label: 'Assign to Caller', desc: 'Change caller assignment', action: 'assignCaller' },
  { icon: Calendar, label: 'Set Follow-up', desc: 'Schedule next contact', action: 'setFollowup' },
  { icon: Shield, label: 'View Broker Lock', desc: 'Check lock status', action: 'viewLock' },
  { icon: RotateCcw, label: 'Extend Access', desc: 'Renew call permission', action: 'extendAccess' },
  { icon: AlertTriangle, label: 'Raise Issue', desc: 'Report a problem', action: 'raiseIssue' },
];

const LeadActionBottomSheet: React.FC<LeadActionBottomSheetProps> = ({
  isOpen,
  onClose,
  leadAlias,
  onAction,
}) => {
  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div
            className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />
          <motion.div
            className="fixed bottom-0 left-0 right-0 bg-zinc-900 rounded-t-2xl z-50 max-h-[80vh] overflow-y-auto"
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
          >
            <div className="p-6">
              <div className="flex justify-between items-center mb-6">
                <h3 className="text-lg font-bold text-white">Lead {leadAlias}</h3>
                <button
                  onClick={onClose}
                  aria-label="Close lead actions"
                  className="p-2 rounded-full hover:bg-white/5 transition-colors"
                >
                  <X className="w-5 h-5 text-zinc-400" />
                </button>
              </div>

              <p className="text-sm text-zinc-400 mb-6">
                Contact details are protected. All actions use secure bridge.
              </p>

              <div className="space-y-3">
                {actions.map((action, index) => (
                  <motion.button
                    key={action.action}
                    className="w-full flex items-center gap-4 p-4 bg-zinc-800/50 border border-white/5 rounded-xl hover:bg-zinc-800 transition-colors text-left"
                    onClick={() => {
                      onAction(action.action);
                      onClose();
                    }}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.05 }}
                    whileTap={{ scale: 0.98 }}
                  >
                    <div className="w-10 h-10 bg-zinc-700 rounded-lg flex items-center justify-center">
                      <action.icon className="w-5 h-5 text-zinc-300" />
                    </div>
                    <div>
                      <p className="text-sm font-medium text-white">{action.label}</p>
                      <p className="text-xs text-zinc-400">{action.desc}</p>
                    </div>
                  </motion.button>
                ))}
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default LeadActionBottomSheet;

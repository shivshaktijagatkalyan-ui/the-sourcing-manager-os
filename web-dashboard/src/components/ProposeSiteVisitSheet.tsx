'use client';

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Send } from 'lucide-react';

interface ProposeSiteVisitSheetProps {
  isOpen: boolean;
  onClose: () => void;
  leadAlias: string;
  projects: Array<{ id: string; name: string; area: string }>;
  onPropose: (projectId: string, date: string, time: string, notes: string) => void;
}

const ProposeSiteVisitSheet: React.FC<ProposeSiteVisitSheetProps> = ({
  isOpen,
  onClose,
  leadAlias,
  projects,
  onPropose,
}) => {
  const [selectedProject, setSelectedProject] = useState('');
  const [selectedDate, setSelectedDate] = useState('');
  const [selectedTime, setSelectedTime] = useState('');
  const [notes, setNotes] = useState('');

  const handleSubmit = () => {
    if (selectedProject && selectedDate && selectedTime) {
      onPropose(selectedProject, selectedDate, selectedTime, notes);
      onClose();
    }
  };

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
            className="fixed bottom-0 left-0 right-0 bg-zinc-900 rounded-t-2xl z-50 max-h-[90vh] overflow-y-auto"
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
          >
            <div className="p-6">
              <div className="flex justify-between items-center mb-6">
                <h3 className="text-lg font-bold text-white">Propose Site Visit</h3>
                <button
                  onClick={onClose}
                  aria-label="Close site visit proposal"
                  className="p-2 rounded-full hover:bg-white/5 transition-colors"
                >
                  <X className="w-5 h-5 text-zinc-400" />
                </button>
              </div>

              <p className="text-sm text-zinc-400 mb-6">
                Lead {leadAlias} - Schedule a site visit proposal for sourcing manager review.
              </p>

              <div className="space-y-4">
                {/* Project Selection */}
                <div>
                  <label className="block text-sm font-medium text-zinc-300 mb-2">
                    Select Project
                  </label>
                  <select
                    value={selectedProject}
                    onChange={(e) => setSelectedProject(e.target.value)}
                    aria-label="Select project for site visit"
                    className="w-full bg-zinc-800 border border-white/10 rounded-xl px-4 py-3 text-white focus:border-orange-500 focus:outline-none"
                  >
                    <option value="">Choose a project...</option>
                    {projects.map((project) => (
                      <option key={project.id} value={project.id}>
                        {project.name} - {project.area}
                      </option>
                    ))}
                  </select>
                </div>

                {/* Date Selection */}
                <div>
                  <label className="block text-sm font-medium text-zinc-300 mb-2">
                    Preferred Date
                  </label>
                  <input
                    type="date"
                    value={selectedDate}
                    onChange={(e) => setSelectedDate(e.target.value)}
                    aria-label="Preferred site visit date"
                    className="w-full bg-zinc-800 border border-white/10 rounded-xl px-4 py-3 text-white focus:border-orange-500 focus:outline-none"
                    min={new Date().toISOString().split('T')[0]}
                  />
                </div>

                {/* Time Selection */}
                <div>
                  <label className="block text-sm font-medium text-zinc-300 mb-2">
                    Preferred Time
                  </label>
                  <select
                    value={selectedTime}
                    onChange={(e) => setSelectedTime(e.target.value)}
                    aria-label="Preferred site visit time"
                    className="w-full bg-zinc-800 border border-white/10 rounded-xl px-4 py-3 text-white focus:border-orange-500 focus:outline-none"
                  >
                    <option value="">Choose time...</option>
                    <option value="10:00">10:00 AM</option>
                    <option value="11:00">11:00 AM</option>
                    <option value="12:00">12:00 PM</option>
                    <option value="14:00">2:00 PM</option>
                    <option value="15:00">3:00 PM</option>
                    <option value="16:00">4:00 PM</option>
                    <option value="17:00">5:00 PM</option>
                  </select>
                </div>

                {/* Notes */}
                <div>
                  <label className="block text-sm font-medium text-zinc-300 mb-2">
                    Notes (Optional)
                  </label>
                  <textarea
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    aria-label="Site visit notes"
                    placeholder="Any special requirements or notes..."
                    className="w-full bg-zinc-800 border border-white/10 rounded-xl px-4 py-3 text-white focus:border-orange-500 focus:outline-none resize-none"
                    rows={3}
                  />
                </div>
              </div>

              <motion.button
                className={`w-full mt-6 font-semibold py-4 px-4 rounded-xl shadow-lg ${
                  selectedProject && selectedDate && selectedTime
                    ? 'bg-gradient-to-r from-orange-500 to-yellow-500 text-black'
                    : 'bg-zinc-700 text-zinc-400 cursor-not-allowed'
                }`}
                aria-label={`Send site visit proposal for lead ${leadAlias}`}
                disabled={!selectedProject || !selectedDate || !selectedTime}
                whileTap={{ scale: 0.98 }}
                onClick={handleSubmit}
              >
                <div className="flex items-center justify-center gap-2">
                  <Send className="w-5 h-5" />
                  Send Proposal
                </div>
              </motion.button>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};

export default ProposeSiteVisitSheet;

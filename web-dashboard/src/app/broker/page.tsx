import React from 'react';
import BrokerDashboardFutureTrust from '../../components/BrokerDashboardFutureTrust';
import { LeadLoadingOptimization } from '../../components/LeadSearch';

export default function BrokerPage() {
  return (
    <>
      <LeadLoadingOptimization />
      <BrokerDashboardFutureTrust />
    </>
  );
}

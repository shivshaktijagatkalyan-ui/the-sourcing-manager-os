'use client';

import React, { useState } from 'react';
import Image from 'next/image';
import { Shield, Zap, Lock } from 'lucide-react';
import styles from './page.module.css';
import { supabase } from '../lib/supabase';

export default function Home() {
  const [isLoading, setIsLoading] = useState(false);

  const handleGoogleLogin = async () => {
    setIsLoading(true);
    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: typeof window !== 'undefined' ? `${window.location.origin}/auth/callback` : undefined,
        },
      });
      if (error) throw error;
    } catch {
      alert('Login failed. Please check your connection.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className={styles.heroContainer}>
      <div className={styles.heroBackground}></div>
      
      <div className={styles.content}>
        <div className={styles.badge}>
          The Sourcing Manager OS 2.0
        </div>
        
        <h1 className={styles.title}>
          Real Estate Intelligence,<br />
          <span className={styles.titleHighlight}>Elevated.</span>
        </h1>
        
        <p className={styles.subtitle}>
          The ultra-premium, ultra-secure platform for high-performance brokers and sourcing managers. Experience zero data leakage with our proprietary Dataless Security Constitution.
        </p>
        
        <div className={styles.ctaContainer}>
          <a href="/broker" className={styles.primaryButton}>
            Launch Broker OS
          </a>
          <button
            className={styles.googleButton}
            onClick={handleGoogleLogin}
            disabled={isLoading}
          >
            <Image src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" alt="Google" width={18} height={18} />
            <span>{isLoading ? 'Signing in...' : 'Sign in with Google'}</span>
          </button>
          <a href="/broker" className={styles.secondaryButton}>
            Broker Portal
          </a>
        </div>
        
        <div className={styles.featuresGrid}>
          <div className={styles.featureCard}>
            <div className={styles.featureIcon}>
              <Shield size={24} />
            </div>
            <h3 className={styles.featureTitle}>Dataless Constitution</h3>
            <p className={styles.featureDesc}>
              Military-grade PII protection ensures client data never leaves the encrypted vault. Your leads remain entirely yours.
            </p>
          </div>
          
          <div className={styles.featureCard}>
            <div className={styles.featureIcon}>
              <Zap size={24} />
            </div>
            <h3 className={styles.featureTitle}>Smart CRM Routing</h3>
            <p className={styles.featureDesc}>
              AI-driven lead allocation connects high-intent buyers with your top-performing callers instantly.
            </p>
          </div>
          
          <div className={styles.featureCard}>
            <div className={styles.featureIcon}>
              <Lock size={24} />
            </div>
            <h3 className={styles.featureTitle}>Broker Business Vault</h3>
            <p className={styles.featureDesc}>
              A totally isolated ecosystem providing transparent commission tracking and immutable site visit locks.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

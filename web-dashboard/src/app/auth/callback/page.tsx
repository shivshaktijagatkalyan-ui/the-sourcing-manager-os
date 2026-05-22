'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '../../../lib/supabase';

export default function AuthCallbackPage() {
  const router = useRouter();

  useEffect(() => {
    const handleCallback = async () => {
      // Supabase-js automatically handles the hash/query params
      // and establishes the session in storage.
      const { data, error } = await supabase.auth.getSession();
      
      if (error) {
        router.push('/?error=auth_callback_failed');
      } else if (data.session) {
        router.push('/broker');
      } else {
        router.push('/');
      }
    };

    handleCallback();
  }, [router]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0F172A] text-white">
      <div className="text-center">
        <div className="mb-4 h-12 w-12 animate-spin rounded-full border-4 border-[#F5B545] border-t-transparent mx-auto"></div>
        <h2 className="text-xl font-semibold">Completing sign-in...</h2>
        <p className="mt-2 text-gray-400">Verifying your secure session</p>
      </div>
    </div>
  );
}

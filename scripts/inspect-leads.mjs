#!/usr/bin/env node
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.join(__dirname, '../.env');
const envContent = fs.readFileSync(envPath, 'utf8');

const getEnv = (key) => {
  const match = envContent.match(new RegExp(`^${key}=(.*)$`, 'm'));
  return match ? match[1].trim() : null;
};

const SUPABASE_URL = getEnv('SUPABASE_URL');
const SUPABASE_ANON_KEY = getEnv('SUPABASE_ANON_KEY');

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function inspect() {
  console.log("=== INSPECTING LEADS_PUBLIC SCHEMA ===\n");

  try {
    // Try to fetch one record to see the schema
    const { data, error } = await supabase
      .from('leads_public')
      .select('*')
      .limit(1);

    if (error) {
      console.log(`Error: ${error.message}`);
      console.log("\nTrying to list available tables...");
      
      // List all tables by trying common names
      const tables = ['leads', 'leads_public', 'brokers', 'brokers_public', 'audit_events', 'audit_trail'];
      
      for (const table of tables) {
        try {
          const { error: err } = await supabase
            .from(table)
            .select('*')
            .limit(0);
          
          if (!err) {
            console.log(`✅ Table exists: ${table}`);
          }
        } catch (e) {
          // skip
        }
      }
    } else {
      console.log("✅ leads_public schema detected:");
      if (data && data.length > 0) {
        console.log("Columns:", Object.keys(data[0]));
      } else {
        console.log("(Table is empty, but accessible)");
      }
    }

  } catch (err) {
    console.error("Error:", err.message);
  }
}

inspect();

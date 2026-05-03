# AGPLv3 Compliance

This project is licensed under the GNU Affero General Public License v3.0.

## Your Obligations

If you use this software to provide a service over a network (e.g. as a SaaS), you MUST:

1. **Provide Source Code**: Any user interacting with the software via a network has the right to receive the complete source code of the version you are running.
2. **Include License**: You must include the original copyright notice and a copy of the AGPLv3 license in all copies.
3. **State Changes**: If you modify the code, you must prominently state that you have done so.

## Why AGPLv3?
The Sourcing Manager OS is a "Trustless" system. For the trust to be verified, the enforcement logic (RLS, Edge Functions, Encryption) must remain open for audit. Closing the source would break the trust guarantee of the "Data Enforcement Layer".

## Data Privacy vs Open Source
- **Code is Open**: The logic that protects the data is public.
- **Data is Private**: The lead data, encryption keys, and database contents are the private property of the broker/operator.

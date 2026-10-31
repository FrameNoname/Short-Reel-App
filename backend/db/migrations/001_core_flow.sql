-- 001_core_flow: additive changes for the real API (safe to run more than once).
-- Run it against an existing database WITHOUT dropping anything:
--   mysql -uroot shortreel < db/migrations/001_core_flow.sql
-- Fresh installs get the same columns from shortreel.sql.

ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `bio` varchar(160) DEFAULT NULL AFTER `avatar_url`;

-- What the simulated payment charged at purchase time (NULL for unlocks).
ALTER TABLE `coin_transactions`
  ADD COLUMN IF NOT EXISTS `price_usd` decimal(6,2) DEFAULT NULL AFTER `balance_after`;

UPDATE `coin_transactions` t JOIN `coin_packs` p ON p.id = t.coin_pack_id
   SET t.price_usd = p.price_usd
 WHERE t.type = 'topup' AND t.price_usd IS NULL;

-- A cancelled plan keeps working until end_date.
ALTER TABLE `subscriptions`
  ADD COLUMN IF NOT EXISTS `cancelled_at` datetime DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `created_at` datetime NOT NULL DEFAULT current_timestamp();

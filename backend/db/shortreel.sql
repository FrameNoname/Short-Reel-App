-- =====================================================================
-- ShortReel APP database  (Group 7, Project 2)
-- MariaDB 10.4 / XAMPP  ->  phpMyAdmin > Import > shortreel.sql > Go
--
-- Passwords are argon2id hashes (varchar(97)), same as the Node.js
-- 'argon2' package defaults (m=65536, t=3, p=4).
-- Demo logins: admin/1111  kestrel_studio/2222  noor.frames/3333
--              mira.lens/4444  tidewater_ai/5555  viewer01/6666
-- =====================================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+07:00";
SET NAMES utf8mb4;

DROP DATABASE IF EXISTS `shortreel`;
CREATE DATABASE `shortreel` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `shortreel`;

-- --------------------------------------------------------
-- users : 3 roles (viewer / creator / admin)
-- --------------------------------------------------------
CREATE TABLE `users` (
  `id`           smallint(5) UNSIGNED NOT NULL AUTO_INCREMENT,
  `username`     varchar(30)  NOT NULL,
  `password`     varchar(97)  NOT NULL,            -- argon2id hash
  `display_name` varchar(50)  DEFAULT NULL,
  `avatar_url`   varchar(255) DEFAULT NULL,
  `role`         enum('viewer','creator','admin') NOT NULL DEFAULT 'viewer',
  `coin_balance` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `created_at`   datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- lookups for search / filter
-- --------------------------------------------------------
CREATE TABLE `genres` (
  `id`   tinyint(3) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `ai_tools` (
  `id`   tinyint(3) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- films : upload metadata + AI label + review status
-- --------------------------------------------------------
CREATE TABLE `films` (
  `id`              smallint(5) UNSIGNED NOT NULL AUTO_INCREMENT,
  `creator_id`      smallint(5) UNSIGNED NOT NULL,     -- creator or admin
  `title`           varchar(100) NOT NULL,
  `synopsis`        varchar(500) DEFAULT NULL,
  `poster_url`      varchar(255) DEFAULT NULL,
  `genre_id`        tinyint(3) UNSIGNED NOT NULL,
  `ai_tool_id`      tinyint(3) UNSIGNED NOT NULL,
  `prompt_credit`   varchar(500) DEFAULT NULL,         -- prompt / tool credit
  `is_ai_generated` tinyint(1) NOT NULL DEFAULT 1,     -- mandatory AI label
  `status`          enum('pending','approved','rejected','taken_down') NOT NULL DEFAULT 'pending',
  `review_note`     varchar(255) DEFAULT NULL,
  `reviewed_by`     smallint(5) UNSIGNED DEFAULT NULL,
  `reviewed_at`     datetime DEFAULT NULL,
  `created_at`      datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `creator_id` (`creator_id`),
  KEY `status` (`status`),
  CONSTRAINT `films_creator_fk` FOREIGN KEY (`creator_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `films_genre_fk`   FOREIGN KEY (`genre_id`)   REFERENCES `genres` (`id`),
  CONSTRAINT `films_tool_fk`    FOREIGN KEY (`ai_tool_id`) REFERENCES `ai_tools` (`id`),
  CONSTRAINT `films_review_fk`  FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- episodes : each one free or coin-priced (set by owner)
-- --------------------------------------------------------
CREATE TABLE `episodes` (
  `id`               smallint(5) UNSIGNED NOT NULL AUTO_INCREMENT,
  `film_id`          smallint(5) UNSIGNED NOT NULL,
  `episode_no`       tinyint(3) UNSIGNED NOT NULL,
  `title`            varchar(100) DEFAULT NULL,
  `video_path`       varchar(255) NOT NULL,          -- file saved by Multer
  `duration_sec`     smallint(5) UNSIGNED NOT NULL DEFAULT 0,  -- for length filter
  `is_free`          tinyint(1) NOT NULL DEFAULT 0,
  `price_coins`      smallint(5) UNSIGNED NOT NULL DEFAULT 0,  -- 0 when free
  PRIMARY KEY (`id`),
  UNIQUE KEY `film_episode` (`film_id`,`episode_no`),
  CONSTRAINT `episodes_film_fk` FOREIGN KEY (`film_id`) REFERENCES `films` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- coin packs (simulated purchase) + coin_transactions (wallet history)
-- --------------------------------------------------------
CREATE TABLE `coin_packs` (
  `id`        tinyint(3) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`      varchar(30) NOT NULL,
  `coins`     smallint(5) UNSIGNED NOT NULL,
  `price_usd` decimal(6,2) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `coin_transactions` (
  `id`            int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`       smallint(5) UNSIGNED NOT NULL,
  `type`          enum('topup','unlock') NOT NULL,
  `amount`        int(11) NOT NULL,                 -- +topup / -unlock
  `balance_after` int(10) UNSIGNED NOT NULL,
  `coin_pack_id`  tinyint(3) UNSIGNED DEFAULT NULL, -- NULL = demo +100 button
  `episode_id`    smallint(5) UNSIGNED DEFAULT NULL,
  `created_at`    datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `ct_user_fk`    FOREIGN KEY (`user_id`)      REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `ct_pack_fk`    FOREIGN KEY (`coin_pack_id`) REFERENCES `coin_packs` (`id`) ON DELETE SET NULL,
  CONSTRAINT `ct_episode_fk` FOREIGN KEY (`episode_id`)   REFERENCES `episodes` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- unlocked_episodes : UNIQUE(user, episode) => a repeated
-- unlock request can never charge twice. Shares are recorded here.
-- --------------------------------------------------------
CREATE TABLE `unlocked_episodes` (
  `id`            int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`       smallint(5) UNSIGNED NOT NULL,
  `episode_id`    smallint(5) UNSIGNED NOT NULL,
  `coins_spent`   smallint(5) UNSIGNED NOT NULL,
  `creator_share` smallint(5) UNSIGNED NOT NULL,    -- coins to the film owner
  `admin_share`   smallint(5) UNSIGNED NOT NULL,    -- coins to the admin
  `created_at`    datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_episode` (`user_id`,`episode_id`),
  CONSTRAINT `ue_user_fk`    FOREIGN KEY (`user_id`)    REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `ue_episode_fk` FOREIGN KEY (`episode_id`) REFERENCES `episodes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- subscriptions : monthly, start and end date
-- --------------------------------------------------------
CREATE TABLE `subscriptions` (
  `id`         smallint(5) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    smallint(5) UNSIGNED NOT NULL,
  `price_usd`  decimal(6,2) NOT NULL DEFAULT 6.99,
  `start_date` date NOT NULL,
  `end_date`   date NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `sub_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- settings : admin revenue share %
-- --------------------------------------------------------
CREATE TABLE `settings` (
  `name`  varchar(30) NOT NULL,
  `value` varchar(50) NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------
-- social : likes, watchlist, comments, follows, reports
-- --------------------------------------------------------
CREATE TABLE `likes` (
  `user_id` smallint(5) UNSIGNED NOT NULL,
  `film_id` smallint(5) UNSIGNED NOT NULL,
  PRIMARY KEY (`user_id`,`film_id`),
  CONSTRAINT `likes_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `likes_film_fk` FOREIGN KEY (`film_id`) REFERENCES `films` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `watchlist` (
  `user_id` smallint(5) UNSIGNED NOT NULL,
  `film_id` smallint(5) UNSIGNED NOT NULL,
  PRIMARY KEY (`user_id`,`film_id`),
  CONSTRAINT `wl_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `wl_film_fk` FOREIGN KEY (`film_id`) REFERENCES `films` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `comments` (
  `id`         int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    smallint(5) UNSIGNED NOT NULL,
  `film_id`    smallint(5) UNSIGNED NOT NULL,
  `body`       varchar(500) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `film_id` (`film_id`),
  CONSTRAINT `cm_user_fk` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `cm_film_fk` FOREIGN KEY (`film_id`) REFERENCES `films` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `follows` (
  `follower_id` smallint(5) UNSIGNED NOT NULL,
  `creator_id`  smallint(5) UNSIGNED NOT NULL,
  PRIMARY KEY (`follower_id`,`creator_id`),
  CONSTRAINT `fo_follower_fk` FOREIGN KEY (`follower_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fo_creator_fk`  FOREIGN KEY (`creator_id`)  REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `reports` (
  `id`          smallint(5) UNSIGNED NOT NULL AUTO_INCREMENT,
  `reporter_id` smallint(5) UNSIGNED NOT NULL,
  `film_id`     smallint(5) UNSIGNED NOT NULL,
  `reason`      varchar(255) NOT NULL,
  `status`      enum('open','resolved') NOT NULL DEFAULT 'open',
  `created_at`  datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  CONSTRAINT `rp_user_fk` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `rp_film_fk` FOREIGN KEY (`film_id`)     REFERENCES `films` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- =====================================================================
-- SEED DATA
-- =====================================================================
INSERT INTO `users` (`id`, `username`, `password`, `display_name`, `role`, `coin_balance`) VALUES
(1, 'admin',          '$argon2id$v=19$m=65536,t=3,p=4$9pmc3spVQZG016dQKTRntw$XKQ+orkoyF6DEOk8/nqGYg7Sr2j3GjjvUtcHHqC0ZYI', 'ShortReel Admin', 'admin',   0),
(2, 'kestrel_studio', '$argon2id$v=19$m=65536,t=3,p=4$jzJs1Xp7qh8vkN6r+swKqA$dJXHT6XjmrzPxgBJsQeAEBkp/z1LUDAODD7/4FonOpE', 'Kestrel Studio',  'creator', 0),
(3, 'noor.frames',    '$argon2id$v=19$m=65536,t=3,p=4$1HH4UWeqK71Uhnd9QK1rEg$y6o0QllHUym4+S0sa+U8lamzvQcrW/E5bSbK9NvoMTo', 'Noor Frames',     'creator', 0),
(4, 'mira.lens',      '$argon2id$v=19$m=65536,t=3,p=4$BP3TMGUVI0TOrmnjw8qY0g$FA5g7vcEbwBQyUWk5l91fwGKWnt5EjaGxYGwd+qflRM', 'Mira Lens',       'creator', 142),
(5, 'tidewater_ai',   '$argon2id$v=19$m=65536,t=3,p=4$gZfcN275USi4ZsZxLDfiRQ$DYWuGEL/kEheF/IDTIDEb4oUBCeLOcawhJEBjuCZsJY', 'Tidewater AI',    'creator', 0),
(6, 'viewer01',       '$argon2id$v=19$m=65536,t=3,p=4$8oRBgmUK816hddiqLabRCA$1kq+0u9LGwgZjEXEg1xkqS9Ivj4vkm4zmrKTHcm4kBQ', 'Demo Viewer',     'viewer',  80);

INSERT INTO `genres` (`id`, `name`) VALUES
(1, 'Drama'), (2, 'Sci-Fi'), (3, 'Romance'), (4, 'Thriller'), (5, 'Fantasy'), (6, 'Mystery');

INSERT INTO `ai_tools` (`id`, `name`) VALUES
(1, 'Text-to-video'), (2, 'Image-to-video'), (3, 'Video-to-video'), (4, 'Mixed');

INSERT INTO `films` (`id`, `creator_id`, `title`, `synopsis`, `genre_id`, `ai_tool_id`, `prompt_credit`, `status`, `reviewed_by`, `reviewed_at`) VALUES
(1, 2, 'Salt & Signal',   'A lighthouse keeper decodes messages from the sea.', 6, 1, 'Prompt: stormy lighthouse, 35mm film look', 'approved', 1, NOW()),
(2, 3, 'Paper Moons',     'Two strangers trade letters across a folded city.',  3, 2, 'Prompt: paper-cut city at night',           'approved', 1, NOW()),
(3, 4, 'Ember Protocol',  'An android firefighter questions her last command.', 2, 1, 'Prompt: android firefighter, cinematic',    'approved', 1, NOW()),
(4, 5, 'Glass Harbour',   'A port town where every reflection remembers.',      5, 3, 'Prompt: glass harbour, dreamlike',          'pending',  NULL, NULL),
(5, 1, 'ShortReel Intro', 'Admin-owned showcase film.',                         1, 4, 'Prompt: montage of AI film styles',         'approved', 1, NOW());

-- 8 episodes per film: ep 1-2 free, ep 3-8 = 20 coins
INSERT INTO `episodes` (`film_id`, `episode_no`, `title`, `video_path`, `duration_sec`, `is_free`, `price_coins`)
SELECT f.id, n.n, CONCAT('Episode ', n.n),
       CONCAT('uploads/film', f.id, '_ep', n.n, '.mp4'),
       60 + n.n * 15,
       IF(n.n <= 2, 1, 0),
       IF(n.n <= 2, 0, 20)
FROM `films` f
CROSS JOIN (SELECT 1 n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
            UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8) n
ORDER BY f.id, n.n;

INSERT INTO `coin_packs` (`id`, `name`, `coins`, `price_usd`) VALUES
(1, 'Starter', 60, 0.99), (2, 'Popular', 330, 4.99), (3, 'Best value', 750, 9.99);

INSERT INTO `settings` (`name`, `value`) VALUES
('admin_share_percent', '30'),
('demo_topup_coins', '100'),
('subscription_price_usd', '6.99');

-- unlocks (70/30 split for creator films, 100% admin for admin film)
INSERT INTO `unlocked_episodes` (`id`, `user_id`, `episode_id`, `coins_spent`, `creator_share`, `admin_share`)
SELECT 1, 4, id, 20, 14, 6 FROM `episodes` WHERE film_id = 1 AND episode_no = 3;
INSERT INTO `unlocked_episodes` (`id`, `user_id`, `episode_id`, `coins_spent`, `creator_share`, `admin_share`)
SELECT 2, 4, id, 20, 14, 6 FROM `episodes` WHERE film_id = 1 AND episode_no = 4;
INSERT INTO `unlocked_episodes` (`id`, `user_id`, `episode_id`, `coins_spent`, `creator_share`, `admin_share`)
SELECT 3, 6, id, 20, 14, 6 FROM `episodes` WHERE film_id = 3 AND episode_no = 3;
INSERT INTO `unlocked_episodes` (`id`, `user_id`, `episode_id`, `coins_spent`, `creator_share`, `admin_share`)
SELECT 4, 4, id, 20, 0, 20 FROM `episodes` WHERE film_id = 5 AND episode_no = 3;

-- wallet history (adds up to the balances above)
INSERT INTO `coin_transactions` (`user_id`, `type`, `amount`, `balance_after`, `coin_pack_id`, `episode_id`) VALUES
(4, 'topup',  100, 100, NULL, NULL),
(4, 'topup',   60, 160, 1,    NULL),
(4, 'topup',   42, 202, NULL, NULL),
(4, 'unlock', -20, 182, NULL, (SELECT episode_id FROM unlocked_episodes WHERE id = 1)),
(4, 'unlock', -20, 162, NULL, (SELECT episode_id FROM unlocked_episodes WHERE id = 2)),
(4, 'unlock', -20, 142, NULL, (SELECT episode_id FROM unlocked_episodes WHERE id = 4)),
(6, 'topup',  100, 100, NULL, NULL),
(6, 'unlock', -20,  80, NULL, (SELECT episode_id FROM unlocked_episodes WHERE id = 3));

INSERT INTO `subscriptions` (`user_id`, `price_usd`, `start_date`, `end_date`) VALUES
(4, 6.99, CURDATE() - INTERVAL 10 DAY, CURDATE() + INTERVAL 20 DAY);

INSERT INTO `likes` VALUES (4, 1), (6, 3);
INSERT INTO `watchlist` VALUES (4, 2), (4, 3), (6, 1);
INSERT INTO `follows` VALUES (4, 2), (4, 3), (6, 4);
INSERT INTO `comments` (`user_id`, `film_id`, `body`) VALUES
(6, 1, 'The ending of episode 2 was great!'),
(4, 2, 'Love the paper-cut style.');
INSERT INTO `reports` (`reporter_id`, `film_id`, `reason`) VALUES
(6, 2, 'Audio out of sync in episode 4');

COMMIT;

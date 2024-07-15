-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jul 15, 2024 at 09:17 AM
-- Server version: 8.0.30
-- PHP Version: 8.1.10

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `rentalmobil2`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_CallTableMobil` ()   BEGIN
	SELECT * FROM mobil;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_GetMobilByModelAndTahun` (IN `model_mobil` VARCHAR(10), IN `tahun_mobil` VARCHAR(10))   BEGIN
	SELECT * FROM mobil WHERE Model = model_mobil AND Tahun = tahun_mobil;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_MobilBelowOrAboveAverage` (IN `status` VARCHAR(10), IN `merek` VARCHAR(10))   BEGIN
    DECLARE AverageSewa DECIMAL(10,2);
    SELECT AVG(Harga_sewa) INTO AverageSewa FROM mobil;
    IF status = 'Above' THEN
        SELECT * FROM mobil WHERE mobil.Harga_sewa > AverageSewa AND mobil.Merek = merek;
    ELSEIF status = 'Below' THEN
        SELECT * FROM mobil WHERE mobil.Harga_sewa < AverageSewa AND mobil.Merek = merek;
    ELSE
        SELECT 'Invalid status';
    END IF;
END$$

--
-- Functions
--
CREATE DEFINER=`root`@`localhost` FUNCTION `CountAvailableCarsByModelAndYear` (`model_mobil` VARCHAR(50), `tahun_mobil` INT) RETURNS INT DETERMINISTIC READS SQL DATA BEGIN
    DECLARE jumlah_mobil INT;
    SELECT COUNT(*) INTO jumlah_mobil FROM mobil WHERE Model =  model_mobil AND Tahun = tahun_mobil AND Status = 'TERSEDIA'; 
    RETURN jumlah_mobil;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `GetRataRataHargaMobil` () RETURNS DECIMAL(10,2) DETERMINISTIC READS SQL DATA BEGIN
    DECLARE rata_rata DECIMAL(10,2);
    SELECT AVG(Harga_Sewa) INTO rata_rata FROM mobil;
    RETURN rata_rata;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `log_history`
--

CREATE TABLE `log_history` (
  `ID_Log` int NOT NULL,
  `ID_Transaksi` int DEFAULT NULL,
  `Tanggal` timestamp NULL DEFAULT NULL,
  `Deskripsi_Activity` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `lokasi`
--

CREATE TABLE `lokasi` (
  `ID_Lokasi` int NOT NULL,
  `Nama_Lokasi` varchar(100) DEFAULT NULL,
  `Alamat` text,
  `Kota` varchar(50) DEFAULT NULL,
  `Telepon` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `mobil`
--

CREATE TABLE `mobil` (
  `ID_Mobil` int NOT NULL,
  `Merek` varchar(50) DEFAULT NULL,
  `Model` varchar(50) DEFAULT NULL,
  `Tahun` int DEFAULT NULL,
  `Harga_Sewa` int DEFAULT NULL,
  `Status` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Triggers `mobil`
--
DELIMITER $$
CREATE TRIGGER `after_delete_mobil` AFTER DELETE ON `mobil` FOR EACH ROW BEGIN
    DECLARE existing_count INT;
    DECLARE available_count INT;

    SELECT jumlah, jumlah_available INTO existing_count, available_count
    FROM model_mobil_log
    WHERE model = OLD.Model AND tahun = OLD.Tahun
    LIMIT 1;

    IF existing_count IS NOT NULL THEN
        UPDATE model_mobil_log
        SET jumlah = jumlah + 1, 
            jumlah_available = jumlah_available - IF(OLD.Status = 'TERSEDIA', 1, 0)
        WHERE model = OLD.Model AND tahun = OLD.Tahun;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `after_insert_mobil` AFTER INSERT ON `mobil` FOR EACH ROW BEGIN
    DECLARE existing_count INT;
    DECLARE available_count INT;

    SELECT jumlah, jumlah_available INTO existing_count, available_count
    FROM model_mobil_log
    WHERE model = NEW.Model AND tahun = NEW.Tahun
    LIMIT 1;

    IF existing_count IS NOT NULL THEN
        UPDATE model_mobil_log
        SET jumlah = jumlah + 1, 
            jumlah_available = jumlah_available + IF(NEW.Status = 'TERSEDIA', 1, 0)
        WHERE model = NEW.Model AND tahun = NEW.Tahun;
    ELSE
        INSERT INTO model_mobil_log (model, tahun, jumlah, jumlah_available)
        VALUES (NEW.Model, NEW.Tahun, 1, IF(NEW.Status = 'TERSEDIA', 1, 0));
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `after_update_available_mobil` AFTER UPDATE ON `mobil` FOR EACH ROW BEGIN
    IF OLD.Status <> NEW.Status THEN
        IF OLD.Status = 'TERSEDIA' THEN
            UPDATE model_mobil_log
            SET jumlah_available = jumlah_available - 1
            WHERE model = OLD.Model AND tahun = OLD.Tahun;
        END IF;

        IF NEW.Status = 'TERSEDIA' THEN
            UPDATE model_mobil_log
            SET jumlah_available = jumlah_available + 1
            WHERE model = NEW.Model AND tahun = NEW.Tahun;
        END IF;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `before_delete_mobil` BEFORE DELETE ON `mobil` FOR EACH ROW INSERT INTO mobil_activity_log (activity_id, category, mobil_merek, mobil_model, mobil_tahun, mobil_harga_sewa, mobil_status, activity_date)
	VALUES (OLD.ID_Mobil, "BEFORE DELETE", OLD.Merek, OLD.Model, OLD.Tahun, OLD.Harga_Sewa, OLD.Status, NOW())
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `before_insert_mobil` BEFORE INSERT ON `mobil` FOR EACH ROW INSERT INTO mobil_activity_log (activity_id, category, mobil_merek, mobil_model, mobil_tahun, mobil_harga_sewa, mobil_status, activity_date)
	VALUES (NEW.ID_Mobil, "BEFORE INSERT", NEW.Merek, NEW.Model, NEW.Tahun, NEW.Harga_Sewa, NEW.Status, NOW())
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `before_update_mobil` BEFORE UPDATE ON `mobil` FOR EACH ROW INSERT INTO mobil_activity_log (activity_id, category, mobil_merek, mobil_model, mobil_tahun, mobil_harga_sewa, mobil_status, activity_date)
	VALUES (OLD.ID_Mobil, "BEFORE UPDATE", OLD.Merek, OLD.Model, OLD.Tahun, OLD.Harga_Sewa, OLD.Status, NOW())
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `mobil_activity_log`
--

CREATE TABLE `mobil_activity_log` (
  `activity_id` int DEFAULT NULL,
  `category` varchar(20) DEFAULT NULL,
  `mobil_merek` varchar(50) DEFAULT NULL,
  `mobil_model` varchar(50) DEFAULT NULL,
  `mobil_tahun` int DEFAULT NULL,
  `mobil_harga_sewa` int DEFAULT NULL,
  `mobil_status` varchar(20) DEFAULT NULL,
  `activity_date` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `model_mobil_log`
--

CREATE TABLE `model_mobil_log` (
  `model` varchar(50) DEFAULT NULL,
  `tahun` int DEFAULT NULL,
  `jumlah` int DEFAULT NULL,
  `jumlah_available` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `transaksi`
--

CREATE TABLE `transaksi` (
  `ID_Transaksi` int NOT NULL,
  `ID_User` int DEFAULT NULL,
  `ID_Mobil` int DEFAULT NULL,
  `ID_Lokasi` int DEFAULT NULL,
  `Tgl_Mulai` date DEFAULT NULL,
  `Tgl_Selesai` date DEFAULT NULL,
  `Total_Biaya` int DEFAULT NULL,
  `Status` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `transaksi_indeks`
--

CREATE TABLE `transaksi_indeks` (
  `ID_Transaksi` int DEFAULT NULL,
  `ID_User` int DEFAULT NULL,
  `ID_Mobil` int DEFAULT NULL,
  `Tgl_Mulai` date DEFAULT NULL,
  `Tgl_Selesai` date DEFAULT NULL,
  `Total_Biaya` decimal(10,2) DEFAULT NULL,
  `Status` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user`
--

CREATE TABLE `user` (
  `ID_User` int NOT NULL,
  `Nama` varchar(100) DEFAULT NULL,
  `Email` varchar(100) DEFAULT NULL,
  `No_Telepon` varchar(20) DEFAULT NULL,
  `Alamat` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_horizontal`
-- (See below for the actual view)
--
CREATE TABLE `vw_horizontal` (
`Harga Sewa` int
,`Merek` varchar(50)
,`Model` varchar(50)
,`Tahun` int
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_insidew_cascaded`
-- (See below for the actual view)
--
CREATE TABLE `vw_insidew_cascaded` (
`activity_date` date
,`Harga Sewa` varchar(22)
,`Merek` varchar(50)
,`Model` varchar(50)
,`Tahun` int
,`Tersedia` int
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_inside_local`
-- (See below for the actual view)
--
CREATE TABLE `vw_inside_local` (
`activity_date` date
,`Harga Sewa` varchar(22)
,`Merek` varchar(50)
,`Model` varchar(50)
,`Tahun` int
,`Tersedia` int
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `vw_vertikal`
-- (See below for the actual view)
--
CREATE TABLE `vw_vertikal` (
`activity_date` date
,`Harga Sewa` varchar(22)
,`Merek` varchar(50)
,`Model` varchar(50)
,`Tahun` int
,`Tersedia` int
);

-- --------------------------------------------------------

--
-- Structure for view `vw_horizontal`
--
DROP TABLE IF EXISTS `vw_horizontal`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_horizontal`  AS SELECT `mobil`.`Merek` AS `Merek`, `mobil`.`Model` AS `Model`, `mobil`.`Tahun` AS `Tahun`, `mobil`.`Harga_Sewa` AS `Harga Sewa` FROM `mobil` ;

-- --------------------------------------------------------

--
-- Structure for view `vw_insidew_cascaded`
--
DROP TABLE IF EXISTS `vw_insidew_cascaded`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_insidew_cascaded`  AS SELECT `mb`.`Merek` AS `Merek`, `mb`.`Model` AS `Model`, `mb`.`Tahun` AS `Tahun`, `mbl`.`jumlah_available` AS `Tersedia`, concat('Rp',`mb`.`Harga_Sewa`) AS `Harga Sewa`, `mml`.`activity_date` AS `activity_date` FROM ((`mobil` `mb` join `model_mobil_log` `mbl` on((`mbl`.`model` = `mb`.`Model`))) join `mobil_activity_log` `mml` on((`mml`.`mobil_model` = `mb`.`Model`))) WHERE ((`mb`.`Tahun` >= 2020) AND (`mb`.`Status` = 'TERSEDIA'))WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Structure for view `vw_inside_local`
--
DROP TABLE IF EXISTS `vw_inside_local`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_inside_local`  AS SELECT `mb`.`Merek` AS `Merek`, `mb`.`Model` AS `Model`, `mb`.`Tahun` AS `Tahun`, `mbl`.`jumlah_available` AS `Tersedia`, concat('Rp',`mb`.`Harga_Sewa`) AS `Harga Sewa`, `mml`.`activity_date` AS `activity_date` FROM ((`mobil` `mb` join `model_mobil_log` `mbl` on((`mbl`.`model` = `mb`.`Model`))) join `mobil_activity_log` `mml` on((`mml`.`mobil_model` = `mb`.`Model`))) WHERE ((`mb`.`Tahun` >= 2020) AND (`mb`.`Harga_Sewa` >= 300000))WITH LOCAL CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Structure for view `vw_vertikal`
--
DROP TABLE IF EXISTS `vw_vertikal`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vw_vertikal`  AS SELECT `mb`.`Merek` AS `Merek`, `mb`.`Model` AS `Model`, `mb`.`Tahun` AS `Tahun`, `mbl`.`jumlah_available` AS `Tersedia`, concat('Rp',`mb`.`Harga_Sewa`) AS `Harga Sewa`, `mml`.`activity_date` AS `activity_date` FROM ((`mobil` `mb` join `model_mobil_log` `mbl` on((`mbl`.`model` = `mb`.`Model`))) join `mobil_activity_log` `mml` on((`mml`.`mobil_model` = `mb`.`Model`))) ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `log_history`
--
ALTER TABLE `log_history`
  ADD PRIMARY KEY (`ID_Log`),
  ADD KEY `fk_transaksi` (`ID_Transaksi`);

--
-- Indexes for table `lokasi`
--
ALTER TABLE `lokasi`
  ADD PRIMARY KEY (`ID_Lokasi`);

--
-- Indexes for table `mobil`
--
ALTER TABLE `mobil`
  ADD PRIMARY KEY (`ID_Mobil`),
  ADD KEY `IDX_Mobil_Merek_Model` (`Merek`,`Model`);

--
-- Indexes for table `transaksi`
--
ALTER TABLE `transaksi`
  ADD PRIMARY KEY (`ID_Transaksi`),
  ADD KEY `fk_mobil` (`ID_Mobil`),
  ADD KEY `fk_lokasi` (`ID_Lokasi`),
  ADD KEY `IDX_Transaksi_User_Lokasi` (`ID_User`,`ID_Lokasi`);

--
-- Indexes for table `transaksi_indeks`
--
ALTER TABLE `transaksi_indeks`
  ADD KEY `IDX_Transaksi_User_Mobil` (`ID_User`,`ID_Mobil`),
  ADD KEY `ID_Transaksi` (`ID_Transaksi`),
  ADD KEY `ID_Mobil` (`ID_Mobil`);

--
-- Indexes for table `user`
--
ALTER TABLE `user`
  ADD PRIMARY KEY (`ID_User`);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `log_history`
--
ALTER TABLE `log_history`
  ADD CONSTRAINT `fk_transaksi` FOREIGN KEY (`ID_Transaksi`) REFERENCES `transaksi` (`ID_Transaksi`);

--
-- Constraints for table `transaksi`
--
ALTER TABLE `transaksi`
  ADD CONSTRAINT `fk_lokasi` FOREIGN KEY (`ID_Lokasi`) REFERENCES `lokasi` (`ID_Lokasi`),
  ADD CONSTRAINT `fk_mobil` FOREIGN KEY (`ID_Mobil`) REFERENCES `mobil` (`ID_Mobil`),
  ADD CONSTRAINT `fk_user` FOREIGN KEY (`ID_User`) REFERENCES `user` (`ID_User`);

--
-- Constraints for table `transaksi_indeks`
--
ALTER TABLE `transaksi_indeks`
  ADD CONSTRAINT `transaksi_indeks_ibfk_1` FOREIGN KEY (`ID_Transaksi`) REFERENCES `transaksi` (`ID_Transaksi`),
  ADD CONSTRAINT `transaksi_indeks_ibfk_2` FOREIGN KEY (`ID_User`) REFERENCES `user` (`ID_User`),
  ADD CONSTRAINT `transaksi_indeks_ibfk_3` FOREIGN KEY (`ID_Mobil`) REFERENCES `mobil` (`ID_Mobil`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

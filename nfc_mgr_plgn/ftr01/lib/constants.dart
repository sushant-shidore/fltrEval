// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

const Color appColorPink01 = Color.fromARGB(0xFF, 0xE3, 0x0A, 0x7C);
const Color appColorBlue01 = Color.fromARGB(0xFF, 0x00, 0xAF, 0xE9);

enum NFCChipType {unidentified, stIos, stAndroid, nxpIos, nxpAndroid}
enum ResultType {pass, fail, warning, fyi}

const int GPB_S0_DATA_PAGE_START_ADDRESS = 12;
const int GPB_S0_DATA_PAGE_END_ADDRESS = 223;

const int GPB_S1_DATA_PAGE_START_ADDRESS = 0;
const int GPB_S1_DATA_PAGE_END_ADDRESS = 255;

const int NXP_CMD_ACK = 0x0A;
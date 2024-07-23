import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ftr01/constants.dart';
import 'package:ftr01/core/notifier/android_nxp.dart';
import 'package:ftr01/helper.dart';

import 'package:ftr01/core/notifier/android_st.dart';
import 'package:ftr01/core/notifier/ios_st.dart';
import 'package:ftr01/core/notifier/ios_nxp.dart';
import 'package:ftr01/logging.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';



class NFCNotifier extends ChangeNotifier 
{
  final log = logger(NFCNotifier);
  final helper = Helper();
  bool _isProcessing = false;
  String _message = "";
  NFCChipType _nfcChipType = NFCChipType.unidentified;

  bool get isProcessing => _isProcessing;

  String get message => _message;

  Future<void> startNFCOperation(
      {required NFCOperation nfcOperation, String dataType = ""}) async {
    try {
      _isProcessing = true;
      notifyListeners();

      bool isAvail = await NfcManager.instance.isAvailable();

      if (isAvail) {
        if (nfcOperation == NFCOperation.read) {
          _message = "Scanning";
        } else if (nfcOperation == NFCOperation.write) {
          _message = "Writing To Tag";
        }

        notifyListeners();

        Set<NfcPollingOption> pollingOption = <NfcPollingOption>{};
        pollingOption.add(NfcPollingOption.iso14443);
        pollingOption.add(NfcPollingOption.iso15693);
        pollingOption.add(NfcPollingOption.iso18092);

        NfcManager.instance.startSession(pollingOptions: pollingOption, onDiscovered: (NfcTag nfcTag) async 
        {
          if (nfcOperation == NFCOperation.read) 
          {
            await _readFromTag(tag: nfcTag);
          } 
          else if (nfcOperation == NFCOperation.write) 
          {
            await _writeToTag(tag: nfcTag);
            _message = "DONE";
          }

          _isProcessing = false;
          notifyListeners();
          await NfcManager.instance.stopSession();
        }, 
        onError: (e) async 
        {
          _isProcessing = false;
          _message = e.toString();
          notifyListeners();
        });
      } else {
        _isProcessing = false;
        _message = "Please Enable NFC From Settings";
        notifyListeners();
      }
    } catch (e) {
      _isProcessing = false;
      _message = e.toString();
      notifyListeners();
    }
  }

  NFCChipType _identifyNfcChip(Iterable<String> nfcType) {

      NFCChipType nfcChipIdentified = NFCChipType.unidentified;

      if (nfcType.contains("iso15693")){
        log.i(".......... iOS - ST Chip");
        nfcChipIdentified = NFCChipType.stIos;
      } else if (nfcType.contains("nfcv")) {
        log.i(".......... Android - ST Chip");
        nfcChipIdentified = NFCChipType.stAndroid;
      }else if (nfcType.contains("mifare")) {
        log.i(".......... iOS - NXP Chip");
        nfcChipIdentified = NFCChipType.nxpIos;
      } else if (nfcType.contains("mifareultralight")) {
        log.i(".......... Android - NXP Chip");
        nfcChipIdentified = NFCChipType.nxpAndroid;
      } else {
        log.e("Unknown Chip - $nfcType");
        nfcChipIdentified = NFCChipType.unidentified;
      }

      return nfcChipIdentified;
  }

  Future<void> _readFromTag({required NfcTag tag}) async 
  { 
    try 
    {
      var tagData = {...tag.data};

      _nfcChipType = _identifyNfcChip(tagData.keys);

      // for(var entry in tagData.entries) 
      // {
      //   log.i("${entry.key} : ${entry.value}");
      // }

      switch(_nfcChipType)
      {
        case NFCChipType.nxpIos:
        {
          var nxpTag = MiFare.from(tag);

          if(nxpTag == null)
          {
            log.e("Tag found null");
          }
          else
          {
            IosNxp iOSNxpHandler = IosNxp(tag: nxpTag);

            Uint8List adcs = await iOSNxpHandler.readADCS();

            log.i("ADCS Read - ${helper.getHexOfUint8List(adcs)}");

            Stopwatch readTimer = Stopwatch()..start();

            bool passwordResult = await iOSNxpHandler.passwordAuthentication();

            if(passwordResult == true)
            {
              bool s0ReadResult = await iOSNxpHandler.readSector0Data();

              if(s0ReadResult == true)
              {
                bool sectorSwitchResult = await iOSNxpHandler.sectorSwitch(NXP_SEC1_ID);

                if(sectorSwitchResult == true)
                {
                  bool s1ReadResult = await iOSNxpHandler.readSector1Data();

                  if(s1ReadResult == true)
                  {
                    log.i("It took ${readTimer.elapsedMilliseconds}ms to read S0 & S1");
                  }
                  else
                  {
                    log.e("iOS NXP - S1 Read didn't work");
                  }
                }
                else
                {
                  log.e("iOS NXP - Sector Switch didn't work");  
                }
              }
              else
              {
                log.e("iOS NXP - S0 Read didn't work");
              }
            }
            else
            {
              log.e("iOS NXP Read - PWD didn't work");
            }

            readTimer.stop(); 
          }
        }
        break;

        case NFCChipType.nxpAndroid:
        {
          var nxpTag = MifareUltralight.from(tag);

          if(nxpTag == null)
          {
            log.e("Tag found null");
          }
          else
          {
            AndroidNxp androidNxpHandler = AndroidNxp(tag: nxpTag);

            Uint8List adcs = await androidNxpHandler.readADCS();

            log.i("ADCS Read - ${helper.getHexOfUint8List(adcs)}");

            Stopwatch readTimer = Stopwatch()..start();

            bool passwordResult = await androidNxpHandler.passwordAuthentication();

            if(passwordResult == true)
            {
              bool s0ReadResult = await androidNxpHandler.readSector0Data();

              if(s0ReadResult == true)
              {
                bool sectorSwitchResult = await androidNxpHandler.sectorSwitch(NXP_SEC1_ID);

                if(sectorSwitchResult == true)
                {
                  bool s1ReadResult = await androidNxpHandler.readSector1Data();

                  if(s1ReadResult == true)
                  {
                    log.i("It took ${readTimer.elapsedMilliseconds}ms to read S0 & S1");
                  }
                  else
                  {
                    log.e("Android NXP - S1 Read didn't work");
                  }
                }
                else
                {
                  log.e("Android NXP - Sector Switch didn't work");  
                }
              }
              else
              {
                log.e("Android NXP - S0 Read didn't work");
              }
            }
            else
            {
              log.e("Android NXP Read - PWD didn't work");
            }

            readTimer.stop(); 
          }
        }
        break;

        case NFCChipType.stIos:
        {
          var stTag = Iso15693.from(tag);

          if(stTag == null) 
          {
            log.e("Tag found null");
          } 
          else 
          {
            IosSt iOSStHandler = IosSt(tag: stTag);

            bool passwordResult = await iOSStHandler.passwordAuthentication();

            if(passwordResult == true)
            {
              bool readResult = await iOSStHandler.readData();

              if(readResult == false)
              {
                log.e("iOS ST - Read didn't work");
              }
              else
              {
                bool writeResult = await iOSStHandler.writeDataAndVerify();

                if(writeResult == false)
                {
                  log.e("iOS ST - Write didn't work");  
                }
                else
                {
                  log.i("iOS ST - ALL DONE!");
                }
              }
            }
            else
            {
              log.e("iOS ST - PWD didn't work");
            }
          }
        }
        break;

        case NFCChipType.stAndroid:
        {
          var stTag = NfcV.from(tag);

          if(stTag == null) 
          {
            log.e("Tag found null");
          } 
          else 
          {
            AndroidSt androidStHandler = AndroidSt(tag: stTag);

            bool readResult = await androidStHandler.readData();

            if(readResult == false)
            {
              log.e("Android ST - Read didn't work");
            }
            else
            {
              bool pwdResult = await androidStHandler.passwordAuthentication();

              if(pwdResult == false)
              {
                log.e("Android ST - Pwd Auth didn't work");
              }
              else
              {
                bool writeResult = await androidStHandler.writeDataAndVerify();

                if(writeResult == false)
                {
                  log.e("Android ST - Write didn't work");
                }
                else
                {
                  log.i("Android ST - All Done!");
                }
              }
            }
          }
        }
        

        break;

        case NFCChipType.unidentified:
          //intentional fall-through
        default:
          log.i("Can't process an unknown tag type.");
        break;
      }
    }
    catch (e)
    {
      log.e("EXPTN ${e.toString()} in _readFromTag");
    }
  }

  Future<void> _writeToTag({required NfcTag tag}) async 
  {
    var tagData = {...tag.data};

    _nfcChipType = _identifyNfcChip(tagData.keys);

    try
    {
      switch(_nfcChipType)
      {
        case NFCChipType.nxpIos:
        {
          var nxpTag = MiFare.from(tag);

          if(nxpTag == null)
          {
            log.e("Tag found null");
          }
          else
          {
            IosNxp iOSNxpHandler = IosNxp(tag: nxpTag);

            Stopwatch writeTimer = Stopwatch()..start();

            bool passwordResult = await iOSNxpHandler.passwordAuthentication();
            
            if(passwordResult == true)
            {
              bool sec0WriteResult = await iOSNxpHandler.writeSector0Data();

              if(sec0WriteResult == true)
              {
                bool sectorSwitchResult = await iOSNxpHandler.sectorSwitch(NXP_SEC1_ID);

                if(sectorSwitchResult == true)
                {
                  bool sec1WriteResult = await iOSNxpHandler.writeSector1Data();

                  if(sec1WriteResult == true)
                  {
                    log.i("It took ${writeTimer.elapsedMilliseconds}ms to write S0 & S1");
                  }
                  else
                  {
                    log.e("iOS NXP - S1 Write didn't work");
                  }
                }
                else
                {
                  log.e("iOS NXP Write - Sector Switch 1 didn't work");  
                }
              }
              else
              {
                log.e("iOS NXP - S0 Write didn't work");
              }

              writeTimer.stop();
            }
            else
            {
              log.e("iOS NXP Write - PWD didn't work");
            }
          }
        }
        break;

        case NFCChipType.nxpAndroid:
        {
          var nxpTag = MifareUltralight.from(tag);

          if(nxpTag == null)
          {
            log.e("Tag found null");
          }
          else
          {
            AndroidNxp androidNxpHandler = AndroidNxp(tag: nxpTag);

            Stopwatch writeTimer = Stopwatch()..start();

            bool passwordResult = await androidNxpHandler.passwordAuthentication();
            
            if(passwordResult == true)
            {
              bool sec0WriteResult = await androidNxpHandler.writeSector0Data();

              if(sec0WriteResult == true)
              {
                bool sectorSwitchResult = await androidNxpHandler.sectorSwitch(NXP_SEC1_ID);

                if(sectorSwitchResult == true)
                {
                  bool sec1WriteResult = await androidNxpHandler.writeSector1Data();

                  if(sec1WriteResult == true)
                  {
                    log.i("It took ${writeTimer.elapsedMilliseconds}ms to write S0 & S1");
                  }
                  else
                  {
                    log.e("Android NXP - S1 Write didn't work");
                  }
                }
                else
                {
                  log.e("Android NXP Write - Sector Switch 1 didn't work");  
                }
              }
              else
              {
                log.e("Android NXP - S0 Write didn't work");
              }

              writeTimer.stop();
            }
            else
            {
              log.e("Android NXP Write - PWD didn't work");
            }
          }
        }        
        break;

        case NFCChipType.stIos:
        break;

        case NFCChipType.stAndroid:
        break;

        case NFCChipType.unidentified:
          //intentional fall-through
        default:
          log.i("Can't process an unknown tag type.");
        break;
      }
    }
    catch (e)
    {
      log.e("EXPTN ${e.toString()} in _writeToTag");
    }
  }

  NdefMessage _createNdefMessage({required String dataType}) {
    switch (dataType) {
      case 'URL':
        {
          return NdefMessage([
            NdefRecord.createUri(
          Uri.parse("https://www.devadnani.com")
          ),
          ]);
        }
      case 'MAIL':
        {
          String emailData = 'mailto:devadnani26@gmail.com';
          return NdefMessage(
            [
              NdefRecord.createUri(
                Uri.parse(emailData),
              ),
            ],
          );
        }
      case 'CONTACT':
        {
          String contactData =
              'BEGIN:VCARD\nVERSION:2.1\nN:John Doe\nTEL:+1234567890\nEMAIL:devadnani26@gmail.com\nEND:VCARD';
          Uint8List contactBytes = utf8.encode(contactData);
          return NdefMessage([
            NdefRecord.createMime(
              'text/vcard',
              contactBytes,
            )
          ]);
        }
      default:
        return const NdefMessage([]);
    }
  }
}


enum NFCOperation { read, write }



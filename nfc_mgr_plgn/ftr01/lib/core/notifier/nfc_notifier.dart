import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ftr01/core/notifier/android_st.dart';
import 'package:ftr01/logging.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:ftr01/core/notifier/ios_st.dart';

class NFCNotifier extends ChangeNotifier 
{
  final log = logger(NFCNotifier);
  bool _isProcessing = false;
  String _message = "";
  NFCChipType _nfcChipType = NFCChipType.Unidentified;

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

        NfcManager.instance.startSession(pollingOptions: pollingOption, onDiscovered: (NfcTag nfcTag) async {
          if (nfcOperation == NFCOperation.read) {
            await _readFromTag(tag: nfcTag);
          } else if (nfcOperation == NFCOperation.write) {
            await _writeToTag(nfcTag: nfcTag, dataType: dataType);
            _message = "DONE";
          }

          _isProcessing = false;
          notifyListeners();
          await NfcManager.instance.stopSession();
        }, onError: (e) async {
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

      NFCChipType nfcChipIdentified = NFCChipType.Unidentified;

      if (nfcType.contains("iso15693")){
        log.i(".......... iOS - ST Chip");
        nfcChipIdentified = NFCChipType.ST_IOS;
      } else if (nfcType.contains("nfcv")) {
        log.i(".......... Android - ST Chip");
        nfcChipIdentified = NFCChipType.ST_ANDROID;
      }else if (nfcType.contains("mifare")) {
        log.i(".......... iOS - NXP Chip");
        nfcChipIdentified = NFCChipType.NXP_IOS;
      } else if (nfcType.contains("mifareultralight")) {
        log.i(".......... Android - NXP Chip");
        nfcChipIdentified = NFCChipType.NXP_ANDROID;
      } else {
        log.e("Unknown Chip - $nfcType");
        nfcChipIdentified = NFCChipType.Unidentified;
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
        case NFCChipType.NXP_IOS:
        break;

        case NFCChipType.NXP_ANDROID:
        break;

        case NFCChipType.ST_IOS:
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

        case NFCChipType.ST_ANDROID:
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
          }
        }
        

        break;

        case NFCChipType.Unidentified:
          //intentional fall-through
        default:
        log.i("Can't process an unknown tag type.");
        break;
      }
    }
    catch (e)
    {
      log.e("EXPTN ${e.toString()} in iOSSt");
    }
  }

  Future<void> _writeToTag(
      {required NfcTag nfcTag, required String dataType}) async {
    NdefMessage message = _createNdefMessage(dataType: dataType);
    await Ndef.from(nfcTag)?.write(message);
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

  void dPrint(String message) 
  {
    debugPrint(message);
  }
}


enum NFCOperation { read, write }

enum NFCChipType {Unidentified, ST_IOS, ST_ANDROID, NXP_IOS, NXP_ANDROID}

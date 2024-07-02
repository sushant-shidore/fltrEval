import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class NFCNotifier extends ChangeNotifier {
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

  Future<void> _readFromTag({required NfcTag tag}) async {
    // String? decodedText;
    // try{
    //   Map<String, dynamic> nfcData = {
    //     'nfca': tag.data['nfca'],
    //     'mifareultralight': tag.data['mifareultralight'],
    //     'ndef': tag.data['ndef']
    //   };

    //   if (nfcData.containsKey('ndef')) {
    //     List<int> payload =
    //         nfcData['ndef']['cachedMessage']?['records']?[0]['payload'];
    //     decodedText = String.fromCharCodes(payload);
    //   }
    // } catch (e) {
    //   decodedText = e.toString();
    // } finally {
    //   _message = decodedText ?? "No Data Found";
    // }

    try {

      var tagData = {...tag.data};

      dPrint("\n");
      //Identify Chip Type
      //
      if (tagData.keys.contains("iso15693")){
        dPrint(".......... iOS - ST Chip");
        _nfcChipType = NFCChipType.ST;
      } else if (tagData.keys.contains("nfcv")) {
        dPrint(".......... Android - ST Chip");
        _nfcChipType = NFCChipType.ST;
      }else if (tagData.keys.contains("mifare")) {
        dPrint(".......... iOS - NXP Chip");
        _nfcChipType = NFCChipType.NXP;
      } else if (tagData.keys.contains("mifareultralight")) {
        dPrint(".......... Android - NXP Chip");
        _nfcChipType = NFCChipType.NXP;
      } else {
        dPrint("Unknown Chip - ${tagData[0].key}");
        _nfcChipType = NFCChipType.Unidentified;
      }

      //dPrint('NFC Tag Detected: ${tag.data}');

      for(var entry in tagData.entries) {
        dPrint("${entry.key} : ${entry.value}");
      }

      if(_nfcChipType == NFCChipType.ST) {
        var stTag = Iso15693.from(tag);

        var requestFlagsForRead = <Iso15693RequestFlag>{};
        requestFlagsForRead.add(Iso15693RequestFlag.highDataRate);

        var requestFlagsForPwdAuth = <Iso15693RequestFlag>{};
        requestFlagsForPwdAuth.add(Iso15693RequestFlag.highDataRate);

        // Uint8List? response = await stTag?.extendedReadSingleBlock(requestFlags: requestFlags, blockNumber: 5);

        // if(response != null){
        //   for(var item in response) {
        //     dPrint(" $item");
        //     }
        // }

        // List<Uint8List>? readData = await stTag?.extendedReadMultipleBlocks(requestFlags: requestFlags, blockNumber: 4, numberOfBlocks: 4);
        // dPrint(readData.toString());

        //Password calculated for ADCS - 12223611000488
        //
        Uint8List feedPassword = Uint8List.fromList([0x01, 0x55, 0xAA, 0x55, 0xAA, 0x9C, 0xDE, 0x2C, 0x74]);
        int pwdCommandCode = 0xB3;

        try {
          Uint8List? pwdResponse = await stTag?.customCommand(requestFlags: requestFlagsForPwdAuth, customCommandCode: pwdCommandCode, customRequestParameters: feedPassword);
          // dPrint("Password acepted, response:  ${pwdResponse.toString()}");

          try {
            Uint8List writeData01 = Uint8List(4);
            writeData01[0] = 0xBB;
            writeData01[1] = 0xBB;
            writeData01[2] = 0xCC;
            writeData01[3] = 0xCC;

            int writeDataStartAddress = 20;

            Set<Iso15693RequestFlag> requestFlagsForWrite = {};
            requestFlagsForWrite.add(Iso15693RequestFlag.highDataRate);
            // requestFlagsForWrite.add(Iso15693RequestFlag.address);
            // requestFlagsForWrite.add(Iso15693RequestFlag.option);

            await stTag?.writeSingleBlock(requestFlags: requestFlagsForWrite, blockNumber: writeDataStartAddress, dataBlock: writeData01);

            List<Uint8List> writeData03 = [];
            
            for(int i = 0; i< 10; i++) {
              writeData03.add(writeData01);
            }

            //await stTag?.writeMultipleBlocks(requestFlags: requestFlagsForWrite, blockNumber: writeDataStartAddress, numberOfBlocks: writeData03.length, dataBlocks: writeData03);

            try {

              int blocksToReadAtOnce = 60;
              int totalBlocksToRead = 480;
              int readIterationsRequired = (totalBlocksToRead ~/ blocksToReadAtOnce);   //This is the Flutter way to convert decimal division result into int

              List<Uint8List>? readBuffer = [];
              List<Uint8List>? readData = [];
              
              Stopwatch readTimer = Stopwatch()..start();

              for(int i=0; i<readIterationsRequired; i++){
                readData = await stTag?.extendedReadMultipleBlocks(requestFlags: requestFlagsForRead, blockNumber: writeDataStartAddress, numberOfBlocks: blocksToReadAtOnce);
                writeDataStartAddress += blocksToReadAtOnce;

                if(readData != null){
                  readBuffer.addAll(readData.toList());
                }
              }
              readTimer.stop();
              dPrint("It took ${readTimer.elapsedMilliseconds}ms to read ${readBuffer.length * 4} bytes");

              //List<Uint8List>? readData = await stTag?.readMultipleBlocks(requestFlags: requestFlagsForRead, blockNumber: writeDataStartAddress, numberOfBlocks: 1);
              
              



              //dPrint(readData.toString());
            } catch (e) {
              dPrint("Exception during readback - ${e.toString()}");  
            }

            } catch (e) {
              dPrint("Exception during write - ${e.toString()}");
            }

          } catch(e) {

          if(e.toString().contains("Tag response error")) {
            dPrint("Incorrect PWD");
          } else {
            dPrint("Unhandled exception in Pwd Auth -  ${e.toString()}");
          }

        }

        //List<Uint8> adcsData = [];
        // Uint8List adcsData = Uint8List(4);

        // if(readData != null) {

        //   for(int i = 0; i < readData.length; i++) {
        //     adcsData.insertAll(0, readData[i]);
        //   }

        //   dPrint("adcsData = ${adcsData.buffer}");

        // }
      }

    } catch (e) {
      debugPrint('Error reading NFC: $e');
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

  void dPrint(String message) {
    debugPrint(message);
  }
}

enum NFCOperation { read, write }

enum NFCChipType {Unidentified, ST, NXP}
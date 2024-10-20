import 'dart:typed_data';
import 'dart:async';

import 'package:ftr01/logging.dart';
import 'package:ftr01/helper.dart';
import 'package:nfc_manager/platform_tags.dart';

class AndroidSt
{
  final log = logger(AndroidSt);
  final helper = Helper();

  NfcV? _stTag;

  AndroidSt({required NfcV tag})
  {
    _stTag = tag;
    log.i("identifier: ${helper.getHexOfUint8List(_stTag!.identifier)}");
  }

  Future<bool> passwordAuthentication() async
  {
    bool result = false;

    //Password calculated for ADCS - 12223611000488
    //
    Uint8List feedPassword = Uint8List.fromList([0x01, 0x55, 0xAA, 0x55, 0xAA, 0x9C, 0xDE, 0x2C, 0x74]);

    List<int> pwdCmdBytes = <int>[
      0x22,   // Flags (addressed)
      0xB3,   // Present Password Command
      0x02,   // 'Tag No' - ST has its code as '2'
              // UID - will be added later
              // Protected area - will be added later
              // Password Bytes - will be added later
      ];

    try
    {
      //As part of the command, insert 'Uid' at index 2
      //
      pwdCmdBytes.insertAll(3, _stTag!.identifier);

      //Put the password at the end of the command
      //
      pwdCmdBytes.addAll(feedPassword);

      Uint8List pwdCommand = Uint8List.fromList(pwdCmdBytes);

      Uint8List pwdResponse = await _stTag!.transceive(data: pwdCommand);

      if(pwdResponse.first == 0x00)
      {
        //This means password fed was correct and the authentication is successful
        //
        result = true;
        log.i("Pwd Auth Successful");
      }
      else
      {
        log.e("Pwd Cmd Response failed - ${pwdResponse.first.toRadixString(16) ..padLeft(2) ..toUpperCase()}}");
      }
    }
    catch(e)
    {
      log.e("EXPTN in Android ST Pwd - ${e.toString()}");
    }


    return result;
  }

  Future<bool> writeDataAndVerify() async
  {
    bool result = false;
    int writeDataStartAddress = 20;
    int blocksCanBeWrittenAtOnce = 4;
    int bytesInAblock = 4;
    int totalBlocksToWrite = 300;

    List<Uint8List> writeCommands = List.empty(growable: true);

    int writeIterationsRequired = totalBlocksToWrite ~/ blocksCanBeWrittenAtOnce;
    
    //Fill dummy data to write
    //
    Uint8List blockDataToWrite = Uint8List(blocksCanBeWrittenAtOnce * bytesInAblock);
    blockDataToWrite.fillRange(0, blockDataToWrite.length, 0x5A);

    try
    {
      //First prepare all 'block write' commands at once
      //
      for(int i=0; i < writeIterationsRequired; i++)
      {
        List<int> writeCmdBytes = <int>[
          0x22,   // Flags (addressed)
          0x34,   // Extended Write Multiple Blocks Command
                  // UID - will be added later
          (writeDataStartAddress & 0x00FF),         //Address LSByte
          ((writeDataStartAddress >> 8) & 0x00FF),   //Address MSByte
          ((blocksCanBeWrittenAtOnce - 1) & 0x00FF),         //No of Blocks LSByte - (one less than intended block write as per datasheet)
          (((blocksCanBeWrittenAtOnce - 1) >> 8) & 0x00FF)   //No of Blocks MSByte - (one less than intended block write as per datasheet)
        ];

        //As part of the command, insert 'Uid' at index 2
        //
        writeCmdBytes.insertAll(2, _stTag!.identifier);
        
        //Add bytes to be written
        //
        writeCmdBytes.addAll(blockDataToWrite);

        //log.i("writeCommand #${(i + 1).toString().padLeft(2, '0')}: ${helper.getHexofListUint(writeCmdBytes)}");

        Uint8List writeCommand = Uint8List.fromList(writeCmdBytes);

        writeCommands.add(writeCommand);
        writeDataStartAddress += blocksCanBeWrittenAtOnce;
      }

      //Now send the commands one-by-one. It should be efficient now and will give more accurate write timing
      //
      //Stopwatch writeTimer = Stopwatch()..start();
      
      for(int i=0; i < writeCommands.length; i++)
      {
        Uint8List writeResponse = await _stTag!.transceive(data: writeCommands[i]);

        if(writeResponse.first == 0x00)
        {
          //First byte in response of Transceive command denotes success/failure. 0x00 means success
          //
          result = true;
        }
        else
        {
          result = false;

          log.e("Android ST Write Failed, RESP: ${writeResponse[0]}");
          break;
        }
      }

      // if(result == true)
      // {
      //   writeTimer.stop();
      //   log.i("It took ${writeTimer.elapsedMilliseconds}ms to write ${(totalBlocksToWrite * bytesInAblock)} bytes");
      // }
      // else
      // {
      //   //Operation has failed, so no point in printing timing
      // }
    }
    catch(e)
    {
      log.e("EXPTN in Android ST Write - ${e.toString()}");

      result = false;
    }

    return result;
  }

  Future<bool> readData() async
  {
    bool result = false;

    int readDataStartAddress = 20;
    int totalBlocksToRead = 480;
    int blocksCanBeReadAtOnce = 60;
    
    int readIterationsRequired = (totalBlocksToRead ~/ blocksCanBeReadAtOnce);   //This is the Flutter way to convert decimal division result into int

    List<int> readBuffer = List.empty(growable: true);
    List<Uint8List> readCommands = List.empty(growable: true);

    try
    {
      //First prepare all 'block read' commands at once
      //
      for(int i=0; i < readIterationsRequired; i++)
      {
        List<int> commandBytes = <int>[
            0x22,                                     // Flags (addressed)
            0x33,                                     // Extended read multible blocks
            (readDataStartAddress & 0x00FF),          // LSByte of address
            ((readDataStartAddress >> 8) & 0x00FF),   // MSByte of address
            (blocksCanBeReadAtOnce & 0x00FF),             // LSByte of no of blocks to read
            ((blocksCanBeReadAtOnce >> 8) & 0x00FF),      // MSByte of no of blocks to read
          ];

        //As part of the command, insert 'Uid' at index 2
        //
        commandBytes.insertAll(2, _stTag!.identifier);
        //log.i("readCommand: ${helper.getHexofListUint(commandBytes)}");

        Uint8List readCommand = Uint8List.fromList(commandBytes);

        readCommands.add(readCommand);
        readDataStartAddress += blocksCanBeReadAtOnce;
      }

      //Now send the commands one-by-one. It should be efficient now and will give more accurate read timing
      //
      Stopwatch readTimer = Stopwatch()..start();

      for(int i=0; i < readCommands.length; i++)
      {
        Uint8List readData = await _stTag!.transceive(data: readCommands[i]);
              
        if(readData.first == 0x00)
        {
          //First byte in response of Transceive command denotes success/failure. 0x00 means success
          //
          result = true;

          //Since it's not actual data, it should be removed before further processing
          //
          List<int> processRead =  List<int>.from(readData);
          processRead.removeAt(0);

          readBuffer.addAll(processRead);
        }
        else
        {
          result = false;

          log.e("Android ST Read Failed, RESP: ${readData[0]}");
          break;
        }
      }

      if(result == true)
      {
        readTimer.stop();
        log.i("It took ${readTimer.elapsedMilliseconds}ms to read ${readBuffer.length} bytes");
        // log.i("Data Read: ${helper.getHexofListUint(readBuffer)}");
      }
      else
      {
        //Operation has failed, so no point in printing timing
      }
    }
    catch(e)
    {
      log.e("EXPTN in Android ST Read - ${e.toString()}");

      result = false;
    }

    return result;
  }

}  
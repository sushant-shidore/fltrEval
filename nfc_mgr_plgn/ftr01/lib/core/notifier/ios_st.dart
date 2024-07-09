import 'dart:typed_data';
import 'dart:async';

import 'package:ftr01/logging.dart';
import 'package:nfc_manager/platform_tags.dart';

class IosSt
{
    final log = logger(IosSt);

    Iso15693? _stTag;

    IosSt({required Iso15693 tag})
    {
      _stTag = tag;
    }

    Future<bool> passwordAuthentication() async 
    {
      bool result = false;

      var requestFlagsForPwdAuth = <Iso15693RequestFlag>{};
      requestFlagsForPwdAuth.add(Iso15693RequestFlag.highDataRate); 

      //Password calculated for ADCS - 12223611000488
      //
      Uint8List feedPassword = Uint8List.fromList([0x01, 0x55, 0xAA, 0x55, 0xAA, 0x9C, 0xDE, 0x2C, 0x74]);
      int pwdCommandCode = 0xB3;

      try 
      {
        await _stTag!.customCommand(requestFlags: requestFlagsForPwdAuth, customCommandCode: pwdCommandCode, customRequestParameters: feedPassword);
        result = true;
      } 
      catch(e) 
      {
        if(e.toString().contains("Tag response error")) 
        {
          log.d("Incorrect PWD");
        } 
        else 
        {
          log.e("Unhandled exception in Pwd Auth -  ${e.toString()}");
        }

        result = false;
      }
      return result;
    }

    Future<bool> writeDataAndVerify() async 
    {
      bool result = false;

      try
      {
        Uint8List writeData01 = Uint8List(4);
        writeData01[0] = 0xBB;
        writeData01[1] = 0xBB;
        writeData01[2] = 0xCC;
        writeData01[3] = 0xCC;

        int writeDataStartAddress = 20;

        Set<Iso15693RequestFlag> requestFlagsForWrite = {};
        requestFlagsForWrite.add(Iso15693RequestFlag.highDataRate);

        Set<Iso15693RequestFlag> requestFlagsForRead = {};
        requestFlagsForRead.add(Iso15693RequestFlag.highDataRate);

        List<Uint8List> writeData03 = [];
        int noOfBlocksToWriteAtOnce = 4;  //Anything > 4 doesn't work and API responds with 'Tag response error'. It could be the chip's limitation, as same is the case with Xamarin and React.
        int noOfBytesToWriteAtOnce = noOfBlocksToWriteAtOnce * 4;
        
        for(int i = 0; i< noOfBlocksToWriteAtOnce; i++) 
        {
          writeData03.add(writeData01);
        }

        Stopwatch writeTimer = Stopwatch()..start();
        // for(int i = 0; i < noOfBlocksToWrite; i++) {
        //   await stTag?.extendedWriteSingleBlock(requestFlags: requestFlagsForWrite, blockNumber: writeDataStartAddress, dataBlock: writeData01);

        //   writeDataStartAddress++;
        // }

        int totalBytesWritten =0;
        for(totalBytesWritten = 0; totalBytesWritten < 1216; totalBytesWritten +=noOfBytesToWriteAtOnce ) 
        {
          await _stTag!.extendedWriteMultipleBlocks(requestFlags: requestFlagsForWrite, blockNumber: writeDataStartAddress, numberOfBlocks: writeData03.length, dataBlocks: writeData03);
        }
        totalBytesWritten -= noOfBytesToWriteAtOnce;  //For printing actual number without the last 'loop-escape' increment done

        writeTimer.stop();
        log.i("It took ${writeTimer.elapsedMilliseconds}ms to write $totalBytesWritten bytes");

        try
        {
          List<Uint8List>? readData = await _stTag!.extendedReadMultipleBlocks(requestFlags: requestFlagsForRead, blockNumber: writeDataStartAddress, numberOfBlocks: writeData03.length);
          log.i(readData.toString());

          result = true;
        }
        catch (e)
        {
          log.e("EXPTN in write verify - ${e.toString()}");

          result = false;
        }
      }
      catch (e)
      {
        log.e("EXPTN in write - ${e.toString()}");

        result = false;
      }

      return result;
    }

    Future<bool> readData() async
    {
      bool result = false;
      Set<Iso15693RequestFlag> requestFlagsForRead = {};
      requestFlagsForRead.add(Iso15693RequestFlag.highDataRate);

      int readDataStartAddress = 20;

      try
      {
        int blocksToReadAtOnce = 60;
        int totalBlocksToRead = 480;
        int readIterationsRequired = (totalBlocksToRead ~/ blocksToReadAtOnce);   //This is the Flutter way to convert decimal division result into int

        List<Uint8List>? readBuffer = [];
        List<Uint8List>? readData = [];
          
        Stopwatch readTimer = Stopwatch()..start();

        for(int i=0; i<readIterationsRequired; i++)
        {
          readData = await _stTag!.extendedReadMultipleBlocks(requestFlags: requestFlagsForRead, blockNumber: readDataStartAddress, numberOfBlocks: blocksToReadAtOnce);
          readDataStartAddress += blocksToReadAtOnce;

          readBuffer.addAll(readData.toList());
        }

        readTimer.stop();
        log.i("It took ${readTimer.elapsedMilliseconds}ms to read ${readBuffer.length * 4} bytes");

        //List<Uint8List>? readData = await stTag?.readMultipleBlocks(requestFlags: requestFlagsForRead, blockNumber: writeDataStartAddress, numberOfBlocks: 1);

        //dPrint(readData.toString());

        result = true;
      }
      catch (e)
      {
        log.e("EXPTN in iOS ST Read - ${e.toString}");
        result = false;
      }

      return result;
    }
}
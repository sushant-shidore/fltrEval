import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ftr01/logging.dart';
import 'package:ftr01/helper.dart';
import 'package:ftr01/constants.dart';
import 'package:nfc_manager/platform_tags.dart';

class AndroidNxp
{
  final log = logger(AndroidNxp);
  final helper = Helper();

  MifareUltralight? _nxpTag;

  AndroidNxp({required MifareUltralight tag})
  {
    _nxpTag = tag;
    //log.i("identifier: ${helper.getHexOfUint8List(_nxpTag!.identifier)}");
  }

  Future<Uint8List> readADCS() async
  {
    Uint8List command = Uint8List.fromList([0x30, 0x04]);
    Uint8List adcsData = Uint8List(0);

    try
    {
      Uint8List rxData = await _nxpTag!.transceive(data: command);

      //Making it 'growable' is must so that the last unwanted byte can be removed
      //
      List<int> temp = List.empty(growable: true);

      temp = rxData.toList(growable: true);

      temp.removeLast();

      //ADCS is of 15 bytes, so take out the last one
      //
      adcsData = Uint8List.fromList(temp);
    }
    catch(e)
    {
      log.e("EXPTN in Android NXP ADCS Read - ${e.toString()}");
    }

    return adcsData;
  }

  Future<bool> passwordAuthentication() async 
  {
    bool result = false;

    //Password for 2002 with ADCS 'Abhijeet_Rocks', includes the command code 0x1B at the beginning
    //

    Uint8List command = Uint8List.fromList([0x1B, 114, 107, 138, 117]);

    try
    {
      Uint8List rxData = await _nxpTag!.transceive(data: command);

      if(rxData.contains(NXP_CORRECT_PWD_ACK_BYTE_01) && rxData.contains(NXP_CORRECT_PWD_ACK_BYTE_02))
      {
        //log.i("PWD Worked");

        result = true;
      }
      else
      {
        log.e("PWD Failed");
        result = false;
      }
    }
    catch(e)
    {
      log.e("EXPTN in pwd auth - ${e.toString()}");

      result = false;
    }

    return result;
  }

  Future<bool> readSector0Data() async 
  {
    bool result = false;

    int startAddress = GPB_S0_DATA_PAGE_START_ADDRESS;
    int endAddress = GPB_S0_DATA_PAGE_END_ADDRESS;

    try
    {
      Uint8List command = Uint8List.fromList([0x3A, startAddress, endAddress]);
      Uint8List rxData = await _nxpTag!.transceive(data: command);

      if(rxData.length == ((endAddress - startAddress) + 1) * 4 )
      {
        result = true;
        log.i("Android NXP S0 Data Read - ${rxData.length}, ${helper.getHexOfUint8List(rxData)}");
      }
      else
      {
        log.e("S1 Read failed");
        log.e("RX: ${rxData.length}, ${helper.getHexOfUint8List(rxData)}");
        
        result = false;
      }

      //==================== USING 'ReadPages()' API which reads 4 pages at once ========================//
      // var totalPagesRead = 0;

      // List<int> readBuffer = List.empty(growable: true);
      // int pagesCanBeReadAtOnce = 4; //This is the limit of 'readPages' API

      // for(var currentReadAddress = startAddress; currentReadAddress <= (endAddress - pagesCanBeReadAtOnce); currentReadAddress += pagesCanBeReadAtOnce)
      // {
      //   Uint8List rxData = await _nxpTag!.readPages(pageOffset: currentReadAddress);

      //   if(rxData.length == (pagesCanBeReadAtOnce * 4) )
      //   {
      //     readBuffer.addAll(rxData);

      //     totalPagesRead += pagesCanBeReadAtOnce;

      //     result = true;
      //   }
      //   else
      //   {
      //     log.e("S0 Read failed @ $currentReadAddress");
      //     log.e("RX: ${rxData.length}, ${helper.getHexOfUint8List(rxData)}");
          
      //     result = false;
      //     break;
      //   }
      // }

      // if(result == true)
      // {
      //   log.i("S0 Pages read - $totalPagesRead") ;
      //   log.i("Android NXP S0 Data Read - ${helper.getHexofListUint(readBuffer)}");
      // }
    }
    catch(e)
    {
      log.e("EXPTN in S0 Read - ${e.toString()}");

      result = false;
    }

    return result;
  }

  Future<bool> sectorSwitch(int sectorNumber) async 
  {
    bool result = false;

    Stopwatch sectorSwitchTimer = Stopwatch()..start();

    try
    {
      Uint8List pkt01Command = Uint8List.fromList([0xC2, 0xFF]);

      Uint8List pkt01Rx = await _nxpTag!.transceive(data: pkt01Command);

      if((pkt01Rx.length == 1) && (pkt01Rx.contains(NXP_CMD_ACK)))
      {
        //log.i("SSwitch Pkt 01 Worked");

        //Move on to Pkt 02
        //
        Uint8List pkt02Command = Uint8List.fromList([sectorNumber, 0x00, 0x00, 0x00]);
        
        try
        {
          await _nxpTag!.transceive(data: pkt02Command);
        } 
        catch(e)
        {
          if(e.toString().contains("io_exception"))
          {
            //The NXP chip doesn't respond when the packet 02 of the sector switch is successful.
            //They call this idiotic behavior as 'Passive ACK'. 
            //Because of this, Android always throws 'IO Exception', thinking that the chip is not responding in time 
            //and connection could be lost.
            //So we have to let go of this exception for packet 02 and continue anyway.
            //Same was done in case of Xamarin, which has worked fine.
            //

            //Now we need to confirm if the sector switch has really worked. Otherwise r/w which will be attempted
            //thereafter will fail. So better to be safe than sorry.
            //
            //Now, the chip doesn't have any dedicated function / register to check which sector is currently
            //is currently active. So we come up with a method of our own.
            //Location 0xEA from sector 0 is reserved by NFC chip and cannot be read by user.
            //Reference - NXP NTAG I2C Plus Datasheet NT3H2111_2211.
            //When attempted, chip is supposed to return 0x00 NAK
            //
            //However, reading the same locations from sector 1 is allowed and shouldn't return a NAK
            //
            //So to verify if sector 0 is not active (i.e. sector 1 is active), we'll make a read
            //attempt to restricted memory location. If it returns NAK, then it means S0 is active.
            //If it doesn't, then it means S1 is active
            //
            Uint8List sectorConfirmCommand = Uint8List.fromList([0x3A, 0xEA, 0xEA]);
            Uint8List sectorConfirmRx = await _nxpTag!.transceive(data: sectorConfirmCommand);

            if( (sectorConfirmRx.length == 1) && (sectorConfirmRx.contains(0x00)) )
            {
              //Chip has responded with a NAK, which means sector 0 is active
              //
              // log.i("SEC 0 Active");

              if(sectorNumber == NXP_SEC1_ID)
              {
                result = false;
              }
              else
              {
                result = true;
              }
            }
            else
            {
              // log.i("SEC 1 Active");
              
              if(sectorNumber == NXP_SEC1_ID)
              {
                result = true;
              }
              else
              {
                result = false;
              }
            }
          }
          else
          {
            log.e("EXCPTN Android Switch Sector Pkt02 - ${e.toString()}");
            result = false;
          }
        }
      }
      else
      {
        log.e("SSwitch Pkt 01 Failed");
        result = false;
      }

    }
    catch(e)
    {
      log.e("EXPTN in sector switch - ${e.toString()}");

      result = false;
    }

    sectorSwitchTimer.stop();
    log.i("SectorSwitch took ${sectorSwitchTimer.elapsedMilliseconds}ms");

    return result;
  }

  Future<bool> readSector1Data() async 
  {
   bool result = false;

    int startAddress = GPB_S1_DATA_PAGE_START_ADDRESS;
    int endAddress = GPB_S1_DATA_PAGE_END_ADDRESS;

    try
    {
      Uint8List command = Uint8List.fromList([0x3A, startAddress, endAddress]);
      Uint8List rxData = await _nxpTag!.transceive(data: command);

      if(rxData.length == ((endAddress - startAddress) + 1) * 4 )
      {
        result = true;
        log.i("Android NXP S1 Data Read - ${rxData.length}, ${helper.getHexOfUint8List(rxData)}");
      }
      else
      {
        log.e("S1 Read failed");
        // log.e("RX: ${rxData.length}, ${helper.getHexOfUint8List(rxData)}");
        
        result = false;
      }

      //==================== USING 'ReadPages()' API which reads 4 pages at once ========================//
      // int pagesCanBeReadAtOnce = 4; //This is the limit of 'readPages' API
      // List<int> readBuffer = List.empty(growable: true);

      // var totalPagesRead = 0;

      // for(var currentReadAddress = startAddress; currentReadAddress <= (endAddress - pagesCanBeReadAtOnce); currentReadAddress += pagesCanBeReadAtOnce)
      // {
      //   Uint8List rxData = await _nxpTag!.readPages(pageOffset: currentReadAddress);

      //   if(rxData.length == (pagesCanBeReadAtOnce * 4) )
      //   {
      //     readBuffer.addAll(rxData);

      //     totalPagesRead += pagesCanBeReadAtOnce;

      //     result = true;
      //   }
      //   else
      //   {
      //     log.e("S1 Read failed @ $currentReadAddress");
      //     log.e("RX: ${rxData.length}, ${helper.getHexOfUint8List(rxData)}");
          
      //     result = false;
      //     break;
      //   }
      // }

      // if(result == true)
      // {
      //   log.i("S1 Pages read - $totalPagesRead") ;
      //   log.i("Android NXP S1 Data Read - ${helper.getHexofListUint(readBuffer)}");
      // }
    }
    catch(e)
    {
      log.e("EXPTN in S1 Read - ${e.toString()}");

      result = false;
    }

    return result;
  }

  Future<bool> writeSector0Data() async 
  {
    bool result = false;

    int startAddress = GPB_S0_DATA_PAGE_START_ADDRESS;
    int endAddress = GPB_S0_DATA_PAGE_END_ADDRESS;

    try
    {
      for(int currentWriteAddress = startAddress; currentWriteAddress < endAddress; currentWriteAddress++)
      {
        var dataWriteCommand = Uint8List.fromList([0xA2, currentWriteAddress, 0xAA, 0xAA, 0xAA, 0xAA]);

        var rxData = await _nxpTag!.transceive(data: dataWriteCommand);

        if(rxData.contains(NXP_CMD_ACK) == false)
        {
          log.e("Android NXP Write S0 - Failed at $currentWriteAddress, RX: ${helper.getHexOfUint8List(rxData)}");
          
          result = false;

          //No point in continuing with rest of write procedure
          //
          break;
        }
        else
        {
          //Write successful, move on
          //
          result = true;
          continue;
        }
      }

      if(result == true)
      {
        log.i("Bytes written on S0: ${(endAddress - startAddress + 1) * 4}");
      }
    }
    catch(e)
    {
      log.e("EXPTN in S0 Write - ${e.toString()}");

      result = false;
    }

    return result;
  }

  Future<bool> writeSector1Data() async 
  {
    bool result = false;

    int startAddress = GPB_S1_DATA_PAGE_START_ADDRESS;
    
    //No need to test writing data on the entire sector 1, as on actual controls, roughly 1200 bytes are consumed
    //For which, sector 0 is consumed entirely which has a capacity of 212 pages * 4 = 848 bytes,
    //so we can test writing only 352 bytes / 4 = 88 pages
    //
    //We can test writing data on the entire sector 1, but it won't give us a precise time duration for write,
    //which is what we're seeking in the Flutter NFC evaluation exercise
    //

    //int endAddress = GPB_S1_DATA_PAGE_END_ADDRESS;
    int endAddress = GPB_S1_DATA_PAGE_START_ADDRESS + 88;

    try
    {
      for(var currentWriteAddress = startAddress; currentWriteAddress < endAddress; currentWriteAddress++)
      {
        var dataWriteCommand = Uint8List.fromList([0xA2, currentWriteAddress, 0xBB, 0xBB, 0xBB, 0xBB]);

        var rxData = await _nxpTag!.transceive(data: dataWriteCommand);

        if(rxData.contains(NXP_CMD_ACK) == false)
        {
          log.e("Android NXP Write S1 - Failed at $currentWriteAddress, RX: ${helper.getHexOfUint8List(rxData)}");
          
          result = false;

          //No point in continuing with rest of write procedure
          //
          break;
        }
        else
        {
          //Write successful, move on
          //
          result = true;
          continue;
        }
      }

      if(result == true)
      {
        log.i("Bytes written on S1: ${(endAddress - startAddress + 1) * 4}");
      }
    }
    catch(e)
    {
      log.e("EXPTN in S1 Write - ${e.toString()}");

      result = false;
    }

    return result;
  }

  Future<bool> isChipAvailable() async 
  {
    bool result = false;

    try
    {

    }
    catch(e)
    {
      log.e("EXPTN in Chip Avlbl Check - ${e.toString()}");

      result = false;
    }

    return result;
  }  

}
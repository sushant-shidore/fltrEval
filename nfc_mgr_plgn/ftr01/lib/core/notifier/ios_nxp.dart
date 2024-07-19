import 'dart:typed_data';
import 'dart:async';

import 'package:ftr01/constants.dart';
import 'package:ftr01/logging.dart';
import 'package:ftr01/helper.dart';
import 'package:nfc_manager/platform_tags.dart';

class IosNxp
{
  final log = logger(IosNxp);
  final helper = Helper();

  MiFare? _nxpTag;

  IosNxp({required MiFare tag})
  {
    _nxpTag = tag;
  }

  Future<bool> passwordAuthentication() async 
  {
    bool result = false;

    //Password for 2002 with ADCS 'Abhijeet_Rocks', includes the command code 0x1B at the beginning
    //

    Uint8List command = Uint8List.fromList([0x1B, 114, 107, 138, 117]);

    try
    {
      Uint8List rxData = await _nxpTag!.sendMiFareCommand(command);

      if(rxData.contains(0x12) && rxData.contains(0xED))
      {
        log.i("PWD Worked");

        result = true;
      }
      else
      {
        log.i("PWD Failed");
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
    int pagesToReadAtOnce = 64; //Throws 'tag response error' beyond 65
    int endAddress = GPB_S0_DATA_PAGE_END_ADDRESS;

    int pagesToReadInLastIteration = ((endAddress - startAddress) % pagesToReadAtOnce);

    List<int> readBuffer = List.empty(growable: true);


    try
    {
      var currentReadStartAddress = startAddress;
      var currentReadEndAddress = currentReadStartAddress + pagesToReadAtOnce;

      var totalPagesRead = 0;

      while(currentReadEndAddress < endAddress)
      {
        Uint8List command = Uint8List.fromList([0x3A, currentReadStartAddress, currentReadEndAddress]);

        Uint8List rxData = await _nxpTag!.sendMiFareCommand(command);

        // log.i("Pg $currentReadStartAddress - Pg $currentReadEndAddress");

        if(rxData.length == (pagesToReadAtOnce + 1) * 4)
        {
          readBuffer.addAll(rxData);

          currentReadStartAddress += pagesToReadAtOnce;
          currentReadEndAddress = currentReadStartAddress + pagesToReadAtOnce;

          totalPagesRead += (currentReadEndAddress - currentReadStartAddress);

          result = true;
        }
        else
        {
          log.e("S0 Read failed @ $currentReadStartAddress : $currentReadEndAddress");
          log.e("RX: ${rxData.length}, ${helper.getHexOfUint8List(rxData)}");
          
          result = false;
          break;
        }
      }

      if(result == true)
      {
        if(pagesToReadInLastIteration != 0)
        {
          result = false;

          //Read the leftover pages
          //
          Uint8List command = Uint8List.fromList([0x3A, currentReadStartAddress, endAddress]);
          Uint8List rxData = await _nxpTag!.sendMiFareCommand(command);

          if(rxData.length == (pagesToReadInLastIteration + 1) * 4)
          {
            // log.i("Pg $currentReadStartAddress - Pg $endAddress");

            readBuffer.addAll(rxData);

            totalPagesRead += (endAddress - currentReadStartAddress);

            result = true;
          }
          else
          {
            log.e("S0 Read failed @ $currentReadStartAddress : $currentReadEndAddress");
            log.e("RX: ${rxData.length}, ${helper.getHexOfUint8List(rxData)}");
            
            result = false;
          }
        }
        else
        {
          //NOP - Intentionally kept empty
        }

        if(result == true)
        {
          log.i("S0 Total pages read - $totalPagesRead") ;
          // log.i("iOS NXP S0 Data Read - ${helper.getHexofListUint(readBuffer)}");
        }
      }
    }
    catch(e)
    {
      log.e("EXPTN in S0 Read - ${e.toString()}");

      result = false;
    }

    return result;
  }

  Future<bool> sectorSwitch() async 
  {
    bool result = false;

    try
    {
      Uint8List pkt01Command = Uint8List.fromList([0xC2, 0xFF]);

      Uint8List pkt01Rx = await _nxpTag!.sendMiFareCommand(pkt01Command);

      if((pkt01Rx.length == 1) && (pkt01Rx.contains(NXP_CMD_ACK)))
      {
        log.i("SSwitch Pkt 01 Worked");

        //Move on to Pkt 02
        //
        Uint8List pkt02Command = Uint8List.fromList([0x01, 0x00, 0x00, 0x00]);
        
        Uint8List pkt02Rx = await _nxpTag!.sendMiFareCommand(pkt02Command);

        if(pkt02Rx.isEmpty)
        {
          //For this command, NFC chip doesn't send any data in response which is referred to as
          //'Passive ACK' in the datasheet.
          //
          log.i("SSwitch Pkt 02 Worked");
          
          //Now we need to confirm if sector 1 is really active, otherwise r/w which will be attempted
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
          Uint8List sectorConfirmRx = await _nxpTag!.sendMiFareCommand(sectorConfirmCommand);

          if( (sectorConfirmRx.length == 1) && (sectorConfirmRx.contains(0x00)) )
          {
            //Chip has responded with a NAK, which means sector 0 is active
            //
            log.e("SEC 0 Active");
            result = false;
          }
          else
          {
            log.i("SEC 1 switch confirmed");
            result = true;
          }
        }
        else
        {
          log.e("SSwitch Pkt 02 Failed");

          result = false;
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

    return result;
  }

  Future<bool> readSector1Data() async 
  {
   bool result = false;

    int startAddress = GPB_S1_DATA_PAGE_START_ADDRESS;
    int pagesToReadAtOnce = 64; //Throws 'tag response error' beyond 65
    int endAddress = GPB_S1_DATA_PAGE_END_ADDRESS;

    int pagesToReadInLastIteration = ((endAddress - startAddress) % pagesToReadAtOnce);

    List<int> readBuffer = List.empty(growable: true);


    try
    {
      var currentReadStartAddress = startAddress;
      var currentReadEndAddress = currentReadStartAddress + pagesToReadAtOnce;

      var totalPagesRead = 0;

      while(currentReadEndAddress < endAddress)
      {
        Uint8List command = Uint8List.fromList([0x3A, currentReadStartAddress, currentReadEndAddress]);

        Uint8List rxData = await _nxpTag!.sendMiFareCommand(command);

        if(rxData.length == (pagesToReadAtOnce + 1) * 4 )
        {
          // log.i("Pg $currentReadStartAddress - Pg $currentReadEndAddress");

          readBuffer.addAll(rxData);

          currentReadStartAddress += pagesToReadAtOnce;
          currentReadEndAddress = currentReadStartAddress + pagesToReadAtOnce;

          totalPagesRead += (currentReadEndAddress - currentReadStartAddress);

          result = true;
        }
        else
        {
          log.e("S1 Read failed @ $currentReadStartAddress : $currentReadEndAddress");
          log.e("RX: ${rxData.length}, ${helper.getHexOfUint8List(rxData)}");
          
          result = false;
          break;
        }
      }

      if(result == true)
      {
        if(pagesToReadInLastIteration != 0)
        {
          result = false;

          //Read the leftover pages
          //
          Uint8List command = Uint8List.fromList([0x3A, currentReadStartAddress, endAddress]);
          Uint8List rxData = await _nxpTag!.sendMiFareCommand(command);

          if(rxData.length == (pagesToReadInLastIteration + 1) * 4)
          {
            // log.i("Pg $currentReadStartAddress - Pg $endAddress");

            readBuffer.addAll(rxData);

            totalPagesRead += (endAddress - currentReadStartAddress);

            result = true;
          }
          else
          {
            log.e("S1 Read failed @ $currentReadStartAddress : $currentReadEndAddress");
            log.e("RX: ${rxData.length}, ${helper.getHexOfUint8List(rxData)}");
            
            result = false;
          }
        }
        else
        {
          //NOP - Intentionally kept empty
        }

        if(result == true)
        {
          log.i("S1 Total pages read - $totalPagesRead");
          // log.i("iOS NXP S0 Data Read - ${helper.getHexofListUint(readBuffer)}");
        }
      }
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

    try
    {

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

    try
    {

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

  Future<Uint8List> readADCS() async
  {
    Uint8List command = Uint8List.fromList([0x30, 0x04]);
    Uint8List adcsData = Uint8List(0);

    try
    {
      Uint8List rxData = await _nxpTag!.sendMiFareCommand(command);

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
      log.e("EXPTN in iOS NXP ADCS Read - ${e.toString()}");
    }

    return adcsData;
  }
  
}
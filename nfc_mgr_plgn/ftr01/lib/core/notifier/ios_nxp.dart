import 'dart:typed_data';
import 'dart:async';

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

  Future<bool> readSector0Data() async 
  {
    bool result = false;

    try
    {

    }
    catch(e)
    {
      log.e("EXPTN in S0 Read - ${e.toString()}");

      result = false;
    }

    return result;
  }

  Future<bool> readSector1Data() async 
  {
    bool result = false;

    try
    {

    }
    catch(e)
    {
      log.e("EXPTN in S1 Read - ${e.toString()}");

      result = false;
    }

    return result;
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

  Future<bool> sectorSwitch() async 
  {
    bool result = false;

    try
    {

    }
    catch(e)
    {
      log.e("EXPTN in sector switch - ${e.toString()}");

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
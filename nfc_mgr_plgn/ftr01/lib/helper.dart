import 'dart:typed_data';

class Helper
{
  String getHexOfUint8List(Uint8List? input, [bool hide0x = true])
  {
    String result = " ";

    if(input == null)
    {
      result = "Null";
    }
    else
    {
      try
      {
        for(int i=0; i < input.length; i++)
        {
          result += " 0x${input[i]. toRadixString(16). padLeft(2,'0'). toUpperCase()}";
        }

        if(hide0x == true)
        {
          result = result.replaceAll("0x", "");
        }
      }
      catch(e)
      {
        result = "EXPTN in Hex Printing : ${e.toString()}";
      }
    }

    return result;
  }

  String getHexofListUint(List<int>? input, [bool show0x = false])
  {
    String result = " ";

    if(input == null)
    {
      result = "Null";
    }
    else
    {
      try
      {
        for(int i=0; i < input.length; i++)
        {
          result += " 0x${input[i]. toRadixString(16). padLeft(2,'0'). toUpperCase()}";
        }

        if(show0x == false)
        {
          result = result.replaceAll("0x", "");
        }
      }
      catch(e)
      {
        result = "EXPTN in Hex Printing : ${e.toString()}";
      }
    }

    return result;
  }

}
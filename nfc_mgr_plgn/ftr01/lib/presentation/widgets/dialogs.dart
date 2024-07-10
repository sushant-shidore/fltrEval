
import 'package:flutter/material.dart';
import 'package:ftr01/constants.dart';

void scanningDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const AlertDialog(
        title: Text('Scanning Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait...'),
          ],
        ),
      );
    },
  );
}

void showResultDialog(BuildContext context, String message, [String titleText = "Result", String buttonText = "OK"]) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(titleText),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(buttonText),
          ),
        ],
      );
    },
  );
}

void showSnackBar({required BuildContext context, required String message, ResultType type = ResultType.fyi})
{
  Color bgColor = Colors.lightBlue;

  switch(type)
  {
    case ResultType.pass:
      bgColor = Colors.blueAccent;
    break;

    case ResultType.fail:
      bgColor = Colors.redAccent;
    break;

    case ResultType.warning:
      bgColor = Colors.amber;
    break;

    case ResultType.fyi:
    //Intentional fall-through
    default:
      bgColor = Colors.lightBlue;
  }

  final snackBar = SnackBar(
    elevation: 0, 
    duration: const Duration(milliseconds: 3000),
    behavior: SnackBarBehavior.fixed, 
    backgroundColor: bgColor,
    content: Text(message, textAlign: TextAlign.center,),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

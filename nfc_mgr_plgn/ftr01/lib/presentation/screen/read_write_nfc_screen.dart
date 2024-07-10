import 'package:flutter/material.dart';
import 'package:ftr01/core/notifier/nfc_notifier.dart';
import 'package:ftr01/logging.dart';
import 'package:ftr01/presentation/widgets/dialogs.dart';
import 'package:provider/provider.dart';

import 'package:ftr01/constants.dart';

class ReadWriteNFCScreen extends StatelessWidget {
  
  const ReadWriteNFCScreen({super.key});

  @override
  Widget build(BuildContext context) {
    
    bool isIOS = (Theme.of(context).platform == TargetPlatform.iOS);
    final log = logger(ReadWriteNFCScreen);

    isIOS ? log.i("Runing on iPhone") : log.i("Runing on Android");

    return ChangeNotifierProvider(
      create: (context) => NFCNotifier(),
      child: Scaffold(
        appBar: AppBar(
          // title: const Text("WR Connect - Flutter Eval"),
        ),
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  Container(
                    alignment: Alignment.topCenter, 
                    width: 200, 
                    height: 200,
                    decoration: BoxDecoration(border: Border.all(color: Colors.transparent)),
                    child: Image.asset('assets/images/AppLogo_01.png'), ),

                  const SizedBox(height: 20.0,),

                  const Text("Flutter Eval", style: TextStyle(fontSize: 18.0),),

                  const SizedBox(height: 300.0,),

                  MaterialButton(
                    height: 70.0,
                    minWidth: 240.0,
                    //color: Theme.of(context).primaryColor,
                    color: appColorPink01,
                    textColor: Colors.white,
                    splashColor: appColorBlue01,
                    onPressed: () {
                      scanningDialog(context);
                      Provider.of<NFCNotifier>(context, listen: false)
                          .startNFCOperation(nfcOperation: NFCOperation.read);
                    },
                    child: const Text(
                      "Moment of Truth",
                      style: TextStyle(fontSize: 20.0),),),

                  const SizedBox(height: 20.0,),

                  ElevatedButton(
                      onPressed: () {
                        //showResultDialog(context, "Why would you do that?", "Oh no...", "Coz I'm an idiot");

                        showSnackBar(context: context, message: "Please leave.", type: ResultType.fail);
                      },
                      child: const Text("Just don't press this one yet")),

                  const SizedBox(height: 70.0,),

                  Consumer<NFCNotifier>(builder: (context, provider, _) {
                    if (provider.isProcessing) {
                      // return const CircularProgressIndicator();
                    }
                    else
                    {
                      if (provider.message.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Navigator.pop(context);
                          showResultDialog(context, provider.message);
                        });
                      }
                    }
                    return const SizedBox();
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
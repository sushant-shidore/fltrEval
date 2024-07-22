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

    isIOS ? log.i("iPhone") : log.i("Android");

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

                  const SizedBox(height: 20.0,),

                  const Text("Test only on controls \nwith GPB f/w", textAlign: TextAlign.center, style: TextStyle(fontSize: 14.0, color: Colors.redAccent),),

                  const SizedBox(height: 100.0,),

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
                      "READ",
                      style: TextStyle(fontSize: 24.0),),
                  ),

                  const SizedBox(height: 20.0,),

                  MaterialButton(
                    height: 70.0,
                    minWidth: 240.0,
                    //color: Theme.of(context).primaryColor,
                    color: appColorBlue01,
                    textColor: Colors.white,
                    splashColor: appColorPink01,
                    onPressed: () {
                      scanningDialog(context);
                      Provider.of<NFCNotifier>(context, listen: false)
                          .startNFCOperation(nfcOperation: NFCOperation.write);
                    },
                    child: const Text(
                      "WRITE",
                      style: TextStyle(fontSize: 24.0),),
                  ),

                  const SizedBox(height: 30.0,),

                  const Text("Check result on Debug Console of VS Code"),

                  const SizedBox(height: 40,),

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
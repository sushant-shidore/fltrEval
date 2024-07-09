import 'package:flutter/material.dart';
import 'package:ftr01/core/notifier/nfc_notifier.dart';
import 'package:ftr01/presentation/widgets/dialogs.dart';
import 'package:provider/provider.dart';

class ReadWriteNFCScreen extends StatelessWidget {
  const ReadWriteNFCScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NFCNotifier(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("WR Connect - Flutter Eval"),
        ),
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  MaterialButton(
                    height: 70.0,
                    minWidth: 240.0,
                    color: Theme.of(context).primaryColor,
                    textColor: Colors.white,
                    splashColor: Colors.redAccent,
                    onPressed: () {
                      scanningDialog(context);
                      Provider.of<NFCNotifier>(context, listen: false)
                          .startNFCOperation(nfcOperation: NFCOperation.read);
                    },
                    child: const Text(
                      "Moment of Truth",
                      style: TextStyle(fontSize: 24.0),),),

                  const SizedBox(height: 20.0,),

                  ElevatedButton(
                      onPressed: () {
                        showResultDialog(context, "Why did you do that?");
                      },
                      child: const Text("Just don't press this one")),

                  const SizedBox(height: 70.0,),

                  Consumer<NFCNotifier>(builder: (context, provider, _) {
                    if (provider.isProcessing) {
                      return const CircularProgressIndicator();
                    }
                    if (provider.message.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.pop(context);
                        showResultDialog(context, provider.message);
                      });
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
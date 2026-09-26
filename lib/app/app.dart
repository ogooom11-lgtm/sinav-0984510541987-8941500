import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme.dart';
import '../features/legacy/learning_home.dart';
import '../features/lessons/presentation/lessons_home.dart';
class BasiraApp extends StatefulWidget {
  const BasiraApp({super.key});
  @override State<BasiraApp> createState()=>_BasiraAppState();
}
class _BasiraAppState extends State<BasiraApp> {
  @override Widget build(BuildContext context)=>MaterialApp(title:'بصيرة — تعلّم يثبت',debugShowCheckedModeBanner:false,locale:const Locale('ar'),supportedLocales:const [Locale('ar')],localizationsDelegates:GlobalMaterialLocalizations.delegates,
    theme:ThemeData(fontFamily:'BasiraArabic',useMaterial3:true,scaffoldBackgroundColor:const Color(0xfff7f6f3),colorScheme:ColorScheme.fromSeed(seedColor:green),appBarTheme:const AppBarTheme(backgroundColor:Color(0xff252335),foregroundColor:Colors.white,scrolledUnderElevation:0),
      inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:Color(0xffe7e4ed)))),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:green,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(horizontal:24,vertical:18),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))))),home:const LessonsHome(),routes:{'/legacy':(_)=>const LearningHome()});
}

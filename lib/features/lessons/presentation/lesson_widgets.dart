import 'package:flutter/material.dart';
import '../domain/lesson.dart';

class FactCard extends StatelessWidget {
  final LessonFact fact;
  const FactCard(this.fact,{super.key});
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(fact.title,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),
    SelectableText(fact.text,style:const TextStyle(height:1.9,fontSize:18)),const SizedBox(height:12),
    Text(fact.reference,style:Theme.of(context).textTheme.bodySmall),
  ])));
}
class AnswerOption extends StatelessWidget {
  final String text;final bool locked,correct,chosen;final VoidCallback onTap;
  const AnswerOption({super.key,required this.text,required this.locked,required this.correct,required this.chosen,required this.onTap});
  @override Widget build(BuildContext context){
    final color=locked&&correct?Colors.green.shade700:locked&&chosen?Colors.red.shade700:Theme.of(context).colorScheme.primary;
    return Padding(padding:const EdgeInsets.symmetric(vertical:6),child:OutlinedButton(
      onPressed:locked?null:onTap,style:OutlinedButton.styleFrom(alignment:Alignment.centerRight,padding:const EdgeInsets.all(18),side:BorderSide(color:color,width:locked&&(correct||chosen)?2:1)),
      child:Row(children:[if(locked&&(correct||chosen))Padding(padding:const EdgeInsets.only(left:12),child:Icon(correct?Icons.check_circle:Icons.cancel,color:color)),Expanded(child:Text(text,style:TextStyle(color:locked&&(correct||chosen)?color:Theme.of(context).colorScheme.onSurface,fontSize:17,height:1.6)))])));
  }
}

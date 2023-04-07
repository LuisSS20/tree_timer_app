import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:tree_timer_app/common/widgets/check_animation.dart';
import 'package:tree_timer_app/common/widgets/custom_button.dart';
import 'package:tree_timer_app/common/widgets/custom_passwordformfield.dart';
import 'package:tree_timer_app/common/widgets/custom_positioned_login_animations.dart';
import 'package:tree_timer_app/common/widgets/custom_textformfield.dart';
import 'package:tree_timer_app/constants/error_handling.dart';
import 'package:tree_timer_app/constants/utils.dart';
import 'package:tree_timer_app/features/auth_service.dart';
import 'package:tree_timer_app/models/valid_response.dart';

class RegisterForm extends StatefulWidget{

  final AuthService authService;
  final ValueChanged<ValidResponse>? onDispose;
  
  RegisterForm({
    Key? key,
    required this.authService,
    this.onDispose,
  }) : super(key:key);

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm>{
  
  // Use for fields validators
  final _registrationFormKey = GlobalKey<FormState>();

  // Check animation global key
  final _CheckAnimationKey = GlobalKey<CheckAnimationState>();

  final TextEditingController _nameController = new TextEditingController();
  final TextEditingController _emailController = new TextEditingController();
  final TextEditingController _passwordController = new TextEditingController();
  final TextEditingController _confirmPasswordController = new TextEditingController();

  bool isShowLoading =  false;

  void RegisterUser() async{
    // ValidResponse result = await widget.authService.registerUser(context: context,name: _nameController.text,
    // email: _emailController.text,password: _passwordController.text);
    Response res = await widget.authService.registerUser(context: context,name: _nameController.text,
    email: _emailController.text,password: _passwordController.text, confirmpassword: _confirmPasswordController.text);
    // If successful login then successful animation
    ValidResponse validResponse = ValidResponse.fromResponse(res, res.body);
    if(validResponse.isSuccess == true){
      // Trigger check animation
      _CheckAnimationKey.currentState?.triggerCheckFire();
      Future.delayed(Duration(seconds: 2), () async {
        if(mounted)
        {
           setState(() {
            isShowLoading = false;
            });
            // if(widget.onDispose != null){
            //   widget.onDispose!(result);
            // }
            httpErrorHandler(res: res, context: context,
            onSuccess: (){
              showSnackBar(context, returnResponseMessage(validResponse));
            });
        }  
        setState(() {
          isShowLoading = false;
        });
        
        Navigator.pop(context);
      });
      
    }else{ // Error animation
      _CheckAnimationKey.currentState?.triggerErrorFire();
      Future.delayed(Duration(seconds: 2), () async {
        if(mounted){
          setState(() {
            isShowLoading = false;
          });
          showSnackBar(context, returnResponseMessage(validResponse));
        }
      }
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 620,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(60))),
        child: Container(
          width: 310,
          margin: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _registrationFormKey,
                  child: ListView(
                    padding: EdgeInsets.all(20),
                    children: [
                      Center(child: Text("Registro", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      SizedBox(height: 15),
                      CustomTextField(controller: _nameController, labelText: "Nombre"),
                      SizedBox(height: 15),
                      CustomTextField(controller: _emailController, labelText: "Email"),
                      SizedBox(height: 15),
                      CustomPasswordFormField(controller: _passwordController),
                      SizedBox(height: 15),
                      CustomPasswordFormField(controller: _confirmPasswordController),
                      SizedBox(height: 35),
                      Container(
                          width: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        // ignore: prefer_const_constructors
                        child: CustomButton(
                          text: "Crear cuenta",
                          textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          onTap: (){
                            if(_registrationFormKey.currentState!.validate()) {
                              setState(() {
                                isShowLoading = true;
                              });
                              RegisterUser();
                            } 
                          }
                        ),
                      ),
                    ],
                  )
                ),
              ),
              SizedBox(height: 15,),
              isShowLoading ? SizedBox(height: 125, width: 125, child: CheckAnimation(keyChild: _CheckAnimationKey,))
               : const SizedBox(),
              Container(
                height: 100,
                width: 100,
                child: GestureDetector(
                  onTap: (){
                    Navigator.pop(context);
                  },
                  child: Center(
                      child: CircleAvatar(radius: 20, backgroundColor: Colors.grey.shade100, child: Icon(Icons.close),)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

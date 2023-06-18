import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tree_inspection_kit_app/common/widgets/custom_alertdialogtreespecies.dart';
import 'package:tree_inspection_kit_app/common/widgets/custom_camera.dart';
import 'package:tree_inspection_kit_app/common/widgets/custom_floating_buttons_bottom.dart';
import 'package:tree_inspection_kit_app/common/widgets/custom_map.dart';
import 'package:tree_inspection_kit_app/common/widgets/custom_measurements_table.dart';
import 'package:tree_inspection_kit_app/constants/utils.dart';
import 'package:tree_inspection_kit_app/features/tree_data_sheets_service.dart';
import 'package:tree_inspection_kit_app/features/tree_specie_service.dart';
import 'package:tree_inspection_kit_app/models/measurement.dart';
import 'package:tree_inspection_kit_app/models/project.dart';
import 'package:tree_inspection_kit_app/models/tree_data_sheet.dart';
import 'package:tree_inspection_kit_app/models/tree_specie.dart';
import 'package:tree_inspection_kit_app/models/valid_response.dart';


class TreeDataSheetScreen extends StatefulWidget{

  final Project project;
  TreeDataSheet treeDataSheet;
  Directory tmpDir;
  String? specificTreeIdValue;
  TreeSpecie? selectedSpecie;
  String? descriptionValue;
  File? image;

  TreeDataSheetScreen({
    Key? key,
    required this.treeDataSheet,
    required this.project,
    required this.tmpDir,
  }) : super(key:key);

  @override
  State<TreeDataSheetScreen> createState() => _TreeDataSheetScreenState();
}

class _TreeDataSheetScreenState extends State<TreeDataSheetScreen>{

  // Services variables
  TreeSpecieService treeSpecieService = new TreeSpecieService();
  TreeDataSheetService treeDataSheetService = new TreeDataSheetService();

  // TextEditingController variable
  final treeSpecieController = TextEditingController();

  // GlobalKey variables
  final _formKey = GlobalKey<FormState>();
  final _customMapKey = GlobalKey<CustomMapState>();

  // Map variables
  LatLng _position = LatLng(0.0, 0.0);

  // Boolean variable
  bool isEditing = false;


  Future<dynamic> initSpecieValue() async {
    // Get selected specie from value and init it
    if(widget.treeDataSheet.tree_specie_id != '')
    {
      widget.selectedSpecie = TreeSpecie.fromJson(await treeSpecieService.findSpecie(widget.treeDataSheet.tree_specie_id));
      treeSpecieController.value = TextEditingValue(text: widget.selectedSpecie!.name);
    }
    
  }

  // Callback function to delete a measurement from list
  void onDeletedMeasurement(Measurement _measurement){
    if(widget.treeDataSheet.measurements != null)
    {
      widget.treeDataSheet.measurements!.remove(_measurement);
    }
  }

  // Callback function to save image when new picture is taken
  void _saveImage(XFile file) async {
    setState(() {
      // update widget image field
      widget.image = File(file.path);
    });
  }

  // Function which is executed when a data sheet is going to be deleted
  void onDeleted() async {
    bool? deleteDataSheet = await showConfirmDialog(context, "¿Desea borrar la ficha de datos del árbol?", "");
    if(deleteDataSheet == true && widget.treeDataSheet != null){
      Response? res = await treeDataSheetService.deleteTreeDataSheet(context: context, treeDataSheet: widget.treeDataSheet);
      ValidResponse validResponse = ValidResponse(res!);
      showFlutterToast(msg: validResponse.responseMsg, isSuccess: validResponse.isSuccess);
      Navigator.pop(context);
    }else{
      return null;
    }
  }

  // Function which is executed when a project is going to be saved or updated
  void onSaved () async {
    if (_formKey.currentState!.validate())
    {
      if(isEditing == true){
        // Save form values
        _formKey.currentState!.save();
        bool? saveDataSheet = await showConfirmDialog(context, "¿Desea guardar la ficha de datos del árbol?", "");
        if(saveDataSheet == true){
          // Save onto treeDataSheet variable the form values
          widget.treeDataSheet = TreeDataSheet(
            // if new data sheet then empty id
            id: widget.treeDataSheet.id != null ? widget.treeDataSheet.id : '',
            project_id: widget.project.id,
            specific_tree_id: widget.specificTreeIdValue!,
            tree_specie_id: widget.selectedSpecie!.id,
            description: widget.descriptionValue,
            latitude: _position.latitude,
            longitude: _position.longitude,
            // Get base64 content to pass to the request if it is not null
            imageURL: widget.image != null ? base64.encode(widget.image!.readAsBytesSync()) : "",
            measurements: widget.treeDataSheet.measurements,
          );
          // Update data sheet or save if does not exists
          if(widget.treeDataSheet.id != '')
          {
            treeDataSheetService.updateTreeDataSheet(
              context: context,
              treeDataSheet: widget.treeDataSheet as TreeDataSheet,
            );
          }
          else{
            Response? res = await treeDataSheetService.newTreeDataSheet(context: context, treeDataSheet: widget.treeDataSheet as TreeDataSheet);
            // And if res returns a savedDataTreeSheet then we must to update the widget.treedatasheet
            if(res != null)
            {
              showFlutterToastFromResponse(res: res);
              if(res.body.contains('savedTreeDataSheet'))
              {
                setState(() {
                  var data = jsonDecode(res.body);
                  widget.treeDataSheet = TreeDataSheet.fromJson(data['savedTreeDataSheet']);
                });
              }
            }
          }
          // Set isEditing to false
          setState(() {
            isEditing = false;
          });
        }else{
          return null;
        }
      }else{
        setState(() {
          isEditing = true;
        });
      }
    }
  }

  void getCurrentLocation() async {
    // Request permission from user
    final permissionStatus = await Permission.location.request();
    
    // If user allow permission, obtain location
    if (permissionStatus.isGranted) {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _position = LatLng(position.latitude, position.longitude);
        // We call the child widget and update the map
        _customMapKey.currentState!.updateCurrentLocation(_position);
      });
    } else {
      // Show error permission
      showFlutterToast(msg: "Ha denegado el permiso de localización", isSuccess: false);
    }
  }

  // Changes the map type
  void changeMapType() async {
      _customMapKey.currentState!.changeMapType();
  }

  void _showAddItemDialog() {
    double time = 0;
    double distance = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          // This line allows the widget to move up when keyboard appears
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  // Decimal keyboard type
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Distancia (cm)',
                  ),
                  onChanged: (value) {
                    // We need to parse the value string to double type
                    distance = double.tryParse(value) ?? 0.0;
                  },
                ),
                SizedBox(height: 20.0),
                TextFormField(
                  // Decimal keyboard type
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Tiempo (µs)',
                  ),
                  onChanged: (value) {
                    // We need to parse the value string to double type
                    time = double.tryParse(value) ?? 0.0;
                  },
                ),
                SizedBox(height: 20.0),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      double _avgVelocity = (distance/time)*10000;
                      // Only show 2 decimals
                      widget.treeDataSheet.measurements = List.from(widget.treeDataSheet.measurements ?? [])..add(Measurement(time: time, distance: distance, avgVelocity: double.parse(_avgVelocity.toStringAsFixed(2))));
                      Navigator.pop(context);
                    });
                  }  ,
                  child: Text('Agregar'),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  void initState() {
    // If the measurements list is null or empty, it creates an empty list.
    widget.treeDataSheet.measurements ??= List.from(widget.treeDataSheet.measurements ?? []);

    // Initialize value of controller if it is valid
    initSpecieValue();
    // If new data sheet, isEditing = true
    if(widget.treeDataSheet.id == ''){
      isEditing = true;
    }
    super.initState();

    // if data sheet is not null set map position and img, we do this before init the widget
    // to make sure that customMapKey is not null
    if(widget.treeDataSheet != null){
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _position = LatLng(widget.treeDataSheet.latitude!, widget.treeDataSheet.longitude!); 
          _customMapKey.currentState!.updateCurrentLocation(_position);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.treeDataSheet.id.isNotEmpty ? Text(widget.project.name + ' - ' + widget.treeDataSheet.specific_tree_id) : Text(widget.project.name),
      ),
      body: Container(
        margin: EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey,
            width: 1.0, 
          ),
          borderRadius: BorderRadius.circular(5.0), 
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Container(
              padding: EdgeInsets.all(30.0),
              width: double.infinity,
              child: Wrap(
                children: [
                  TextFormField(
                    readOnly: isEditing ? false : true,
                    initialValue: widget.treeDataSheet.specific_tree_id,
                    decoration: const InputDecoration(
                      labelText: 'ID de árbol',
                    ),
                    onSaved: (value) {
                      widget.specificTreeIdValue = value!;
                    },
                    validator: (value) {
                      if(value!.isEmpty){
                        return 'Este campo es obligatorio';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 15,),
                  TextFormField(
                    readOnly: true,
                    controller: treeSpecieController,
                    decoration: const InputDecoration(
                      labelText: 'Especie de árbol',
                    ),
                    validator: (value) {
                      if(value!.isEmpty){
                        return 'Este campo es obligatorio';
                      }
                      return null;
                    },
                  ),
                  isEditing ? Container(
                    width: double.infinity,
                    child: TextButton(
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.grey.shade200)),
                      onPressed: () async {
                        TreeSpecie? selectedSpecie = await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return CustomAlertDialogTreeSpecies();
                          }
                        );
                        // If it is a valid selected specie, then assign to widget
                        if(selectedSpecie != null)
                        {
                          widget.selectedSpecie = selectedSpecie;
                        }
                        // We set the value of tree specie text form field
                        treeSpecieController.value = widget.selectedSpecie != null ? TextEditingValue(text: '${widget.selectedSpecie?.name} (${widget.selectedSpecie?.description})') : const TextEditingValue(text: '');
                      },
                      child: const Text('Seleccionar especie de árbol')
                    ),
                  ) : const SizedBox(height: 80,),
                  const SizedBox(height: 70,),
                  const Center(child: Text("Mediciones", style:  TextStyle(fontWeight: FontWeight.bold),)),
                  const SizedBox(height: 25,),
                  isEditing ? Container(
                    width: double.infinity,
                    child: TextButton(
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.grey.shade200)),
                      onPressed: _showAddItemDialog,
                      child: const Text("Añadir medición")
                    ),
                  ) : SizedBox(),
                  widget.treeDataSheet.measurements != null && widget.treeDataSheet.measurements!.isNotEmpty
                    ? Center(child: CustomMeasurementTable(list: widget.treeDataSheet.measurements!, onDelete: onDeletedMeasurement, isEditing: isEditing,))
                    : SizedBox(),
                  Container(
                    padding: EdgeInsets.only(top: 25, bottom: 25),
                    child: TextFormField(
                      readOnly: isEditing ? false : true,
                      initialValue: widget.treeDataSheet.description,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notas de árbol',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      onSaved: (value) {
                        widget.descriptionValue = value!;
                      },
                    ),
                  ),
                  const SizedBox(height: 20,),
                  Container( child: Center(child: Text("Imagen", style:  TextStyle(fontWeight: FontWeight.bold),))),
                  isEditing ? Container(
                    padding: EdgeInsets.only(bottom: 20),
                    width: double.infinity,
                    child: TextButton(
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.grey.shade200)),
                      // If button pressed then open camera
                      onPressed: (){Navigator.push(context, MaterialPageRoute(builder: (context) => CustomCamera(onSaved: _saveImage,)),);},
                      child: const Text("Añadir imagen")
                    ),
                  ) : Container(padding: EdgeInsets.only(bottom: 25),),
                  // If user loads an image show into screen, if not show url image if is not null or empty
                  widget.image != null ? Container(padding: EdgeInsets.only(bottom: 25) , child: Center(child: Image.file(widget.image as File)))
                  : //Show image if not null or empty
                    (widget.treeDataSheet.imageURL != null && widget.treeDataSheet.imageURL != "")
                      ? Container(
                          padding: EdgeInsets.only(bottom: 25),
                          child: Center(
                            child:  Image.network(
                                      widget.treeDataSheet.imageURL as String,
                            )
                          )
                      ) : const SizedBox(),
                  const SizedBox(height: 20,),
                  const Center(child: Text("Localización", style: TextStyle(fontWeight: FontWeight.bold),)),
                  const SizedBox(height: 5,),
                  isEditing ? Container(
                    width: double.infinity,
                    child: TextButton(
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.grey.shade200)),
                      onPressed: getCurrentLocation,
                      child: const Text('Establecer posición actual')
                    ),
                  ) : const SizedBox(),
                  const SizedBox(height: 10,),
                  // Show map widget
                  CustomMap(key: _customMapKey, currentPosition: _position,),
                  Container(
                    width: double.infinity,
                    child: TextButton(
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Colors.grey.shade200)),
                      onPressed: changeMapType,
                      child: const Text('Cambiar tipo de mapa')
                    ),
                  ),
                ]
              ),
            ),
          ),
        ),
      ),
      // Create floating buttons at the screen bottom
      floatingActionButton: CustomFloatingButtonsBottom(parentWidget: widget, onSaved: onSaved, onDeleted: onDeleted, isEditing: isEditing,),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}



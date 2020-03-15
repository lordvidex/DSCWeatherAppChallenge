import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import './constants.dart';
import 'package:http/http.dart' as http;

//Global variables used throughout widgets since we are using just one dart file

//Parsing the list of cities and their ids
List jsonData;

//Longitude and latitude variables for use by the Location package
double lon, lat;

//To handle all Network call errors
//TODO: If true.. display a certain screen
bool hasError = false;

//Parsed list of cities.. God, how will i sort this thing like this
List<Country> cities;

/************** */
void main() => runApp(MyApp());
/************* */

getCityList(BuildContext context) async {
  jsonData = json.decode(
          await DefaultAssetBundle.of(context).loadString("data/cities.json"))
      as List;
  cities = jsonData
      .map((men) => Country(men['id'].toString(), men['country'], men['name']))
      .toList();
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void didChangeDependencies() {
    getCityList(context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

/*
*All functions goes here
*/
///API Call function that gets user current weather based on current location
///
bool isDefault = true;
String clickedId = '2172797'; //dummy ID

Future<void> getLocation() async {
    Position position;
    position = await Geolocator().getLastKnownPosition(desiredAccuracy: LocationAccuracy.medium);
    if(position==null){
      position = await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    }
    try {
      if(lon==null&&lat==null){
      lon = position.longitude;
      lat = position.latitude;
      }else{
        print(lon);
        print(lat);
      }
    } catch (e) {
      print('Line 110: $e');
      hasError = true;
    }
  }

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    getLocation();
    super.initState();
  }

  ///Location() package for getting user Location
  ///
  ///List of cities to be populated later on screen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('DSC Weather'), actions: <Widget>[
        IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              clickedId = await showSearch<String>(
                  context: context, delegate: DataSearch());
            })
      ]),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              UserCurrentLocation(),
              FlatButton(
                child: Text('CURRENT LOCATION'),
                onPressed: () => setState(() {
                  isDefault = true;
                }),
              )
              //SearchField()
            ]),
      ),
    );
  }
}

//SEarchign class
class DataSearch extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    // Actions to perform on the search Bar
    return [
      IconButton(icon: Icon(Icons.clear), onPressed: () {}),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    // Leading icon of appbar
    return IconButton(
        onPressed: () => close(context, null),
        icon: AnimatedIcon(
          icon: AnimatedIcons.menu_arrow,
          progress: transitionAnimation,
        ));
  }

  @override
  Widget buildResults(BuildContext context) {
    return null;
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestionList = query.isEmpty
        ? cities
        : cities
            .where((cntry) =>
                cntry.name.toLowerCase().contains('${query.toLowerCase()}'))
            .toList();

    return ListView.builder(
        itemCount: suggestionList.length,
        itemBuilder: (ctx, i) => ListTile(
              onTap: () {
                isDefault = false;
                close(context, suggestionList[i].id);
              },
              leading: Icon(Icons.location_city),
              title: Text(suggestionList[i].name),
            ));
  }
}

class UserCurrentLocation extends StatefulWidget {
  @override
  _UserCurrentLocationState createState() => _UserCurrentLocationState();
}

class _UserCurrentLocationState extends State<UserCurrentLocation> {
  Future<Weather> performAPICall() async {
    String url;
    if (isDefault) {
      await getLocation();
      url = '$BASE_URL?lat=$lat&lon=$lon&APPID=$APIKEY';
    } else {
      url = '$BASE_URL?id=$clickedId&APPID=$APIKEY';
    }
    try {
      final response = await http.get(url);
      if (response == null) return throw ('Error fetching Weather Data');
      final root = await json.decode(response.body) as Map<String, dynamic>;
      final data = root['main'];
      final jsonSys = root['sys'];
      return Weather(
          countryName: jsonSys["country"],
          mainDesc: root["weather"][0]['main'],
          iconUrl: '$ICON_BASE_URL${root['weather'][0]['icon']}.png',
          temperature: data['temp'],
          feelslike: data['feels_like'],
          description: root['weather'][0]['description'],
          name: root['name']);
    } catch (e) {
      print('Line 66: $e');
      hasError = true;
      return throw ('Error fetching Weather Data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Weather>(
        future: performAPICall(),
        builder: (context, snapshot) {
          return Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        blurRadius: 2,
                        offset: Offset(2, 2),
                        color: Colors.black),
                    BoxShadow(
                        blurRadius: 5,
                        offset: Offset(-2, -2),
                        color: Colors.white)
                  ]),
              child: snapshot.hasError||hasError
                  ? Text('There was an error getting your current location')
                  : snapshot.connectionState == ConnectionState.waiting
                      ? Center(child: CircularProgressIndicator())
                      : WeatherCard(snapshot.data));
        });
  }
}

class WeatherCard extends StatelessWidget {
  final Weather weather;
  WeatherCard(this.weather);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
              image: NetworkImage(weather.iconUrl),
              fit: BoxFit.contain,
              alignment: Alignment.topRight),
        ),
        child: Column(children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${weather.name}, ${weather.countryName}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text('${weather.mainDesc}, ${weather.description}'),
          Center(
            child: Text('${(weather.temperature - 273).round()}\u{2103}',
                style: Theme.of(context).textTheme.display2),
          ),
          Text('${(weather.feelslike - 273).round()}\u{2103}'),
        ]),
      ),
    );
  }
}

class Weather {
  final String iconUrl;
  final String countryName;
  final String mainDesc;
  final double temperature;
  final String name;
  final String description;
  final double feelslike;
  Weather(
      {this.temperature,
      this.mainDesc,
      this.countryName,
      this.name,
      this.description,
      this.feelslike,
      this.iconUrl});
}

class Country {
  final String id;
  final String name;
  final String country;
  Country(this.id, this.country, this.name);
}

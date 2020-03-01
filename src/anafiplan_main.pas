{********************************************************}
{                                                        }
{   Konnvertierung Flight Plan zu GPX für Parrot ANAFI   }
{                                                        }
{       Copyright (c) 2019         Helmut Elsner         }
{                                                        }
{       Compiler: FPC 3.0.4   /    Lazarus 2.0.4         }
{                                                        }
{ Pascal programmers tend to plan ahead, they think      }
{ before they type. We type a lot because of Pascal      }
{ verboseness, but usually our code is right from the    }
{ start. We end up typing less because we fix less bugs. }
{           [Jorge Aldo G. de F. Junior]                 }
{********************************************************}

(*
This source is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.

This code is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

A copy of the GNU General Public License is available on the World Wide Web
at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
to the Free Software Foundation, Inc., 51 Franklin Street - Fifth Floor,
Boston, MA 02110-1335, USA.

================================================================================

Conversion Flight Plan to GPX for Parrot Anafi Quadkopters
----------------------------------------------------------

{
  "version": 1,
  "title": "WH2-2 ",
  "product": "ANAFI_4K",
  "productId": 2324,
  "uuid": "WH2-2 ",
  "date": 1574192851078,
  "progressive_course_activated": true,
  "dirty": false,
  "longitude": -16.710370033979416,
  "latitude": 28.0944299256001,
  "longitudeDelta": 5.682930350339177E-4,
  "latitudeDelta": 9.701302902698217E-5,
  "zoomLevel": 20.771486282348633,
  "rotation": 0,
  "tilt": 0.17578125,
  "mapType": 4,
  "plan": {
    "takeoff": [
      {
        "type": "VideoStartCapture",
        "cameraId": 0,
        "resolution": 2073600,
        "fps": 30
      }
    ],
    "poi": [
      {
        "latitude": 28.102366066935762,
        "longitude": -16.709989160299305,
        "altitude": 131,
        "color": -7589836
      }
    ],
    "wayPoints": [
      {
        "latitude": 28.094404193482596,
        "longitude": -16.7103760689497,
        "altitude": 17,
        "yaw": -41.96111297607422,
        "speed": 6,
        "continue": true,
        "followPOI": false,
        "follow": 0,
        "lastYaw": -41.96111297607422
        "actions": [
          {
            "type": "Panorama",
            "angle": 360,
            "speed": 4
          }
        ]
      },
...
      {
        "latitude": 28.09445240422642,
        "longitude": -16.710367687046528,
        "altitude": 4,
        "yaw": -56.73773193359375,
        "speed": 5,
        "continue": true,
        "followPOI": false,
        "follow": 0,
        "lastYaw": -56.73773193359375
      }
    ]
  }
}

----------------------------------------------------------------------------
History:
0.1  2019-11-20 Proof of concept, no functionality
0.2  2019-11-22 Funktionalität, volle Auswertung der bekannten Werte
0.3  2019-11-23 Linear interpolated trackpoints between waypoints
1.0  2019-11-24 Number additional trkpt according delta
                altidude and distance (3D), results in more trackpoints.

*)

unit AnafiPlan_main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LCLtype, Forms, Controls, Graphics, Dialogs, Buttons, ComCtrls,
  Grids, fpjson, jsonparser, dateutils, lclintf, StdCtrls, Spin, XMLPropStorage,
  math;

{$I a_plan_en.inc}                                  {Include a language file}
{.$I a_plan_es.inc}
{.$I a_plan_fr.inc}
{.$I a_plan_de.inc}

type

  { TForm1 }

  TForm1 = class(TForm)
    btnOpen: TBitBtn;
    btnClose: TBitBtn;
    cbTrkpt: TCheckBox;
    lblRate: TLabel;
    OpenDialog1: TOpenDialog;
    PageControl1: TPageControl;
    speRate: TSpinEdit;
    StatusBar1: TStatusBar;
    pMeta: TTabSheet;
    pWaypoints: TTabSheet;
    POIgrid: TStringGrid;
    MetaGrid: TStringGrid;
    WPgrid: TStringGrid;
    XMLPropStorage1: TXMLPropStorage;
    procedure btnCloseClick(Sender: TObject);
    procedure btnOpenClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDblClick(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MetaGridKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure POIgridDblClick(Sender: TObject);
    procedure POIgridKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure StatusBar1DblClick(Sender: TObject);
    procedure WPgridDblClick(Sender: TObject);
    procedure WPgridKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure WPgridSelection(Sender: TObject; aCol, aRow: Integer);
  private
    procedure OpenPlanFile;
  public

  end;

const
  appName='AnafiPlanToGPX';
  appvers='1.0';
  appbuild='2019-11-24';
  mymail='helmut.elsner@live.com';
  tab1=' ';
  tab2='  ';
  tab4='    ';
  strich='---------';
  plh='###';

  frmCoord='0.000000000';
  frmZahl='0.00';
  frmKurz='0.0';
  ymd='yyyy-mm-dd';
  hns='hh:nn:ss';

{Links}
  gmapURL='https://maps.google.com/maps';

{JSON keywords}
{Level 0}
  vers='version';
  title='title';
  prod='product';
  prodID='productId';
  UUID='uuid';
  dt='date';
  pca= 'progressive_course_activated';
  dirt='dirty';
  lond='longitudeDelta';
  latd='latitudeDelta';
  zoom='zoomLevel';
  rota='rotation';
  tilt='tilt';
  maptyp='mapType';
  plan='plan';

{Level 1}
  takeoff='takeoff';
  poi='poi';
  wp='wayPoints';
  typ='type';
  camID='cameraId';
  res='resolution';
  fps='fps';
  colr='color';

{Level 2}
  lat='latitude';
  lon='longitude';
  alt='altitude';
  yaw='yaw';
  speed='speed';
  cont='continue';
  followPOI='followPOI';
  follow='follow';
  lastyaw='lastYaw';
  actions='actions';
  angle='angle';

{Strings fpr KML or GPX}
  xmlvers='<?xml version="1.0" encoding="UTF-8"?>'; {ID XML/GPX header}
  gpxvers='<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1">';
  GPXlat=' lat="';
  GPXlon='" lon="';
  GPXet1=' </wpt>';
  wpttag='<wpt';
  gzoom='16';                                      {Zoom value for maps}
  namtag='name>';



var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure ShowAbout;                               {AboutBox}
begin
  MessageDlg(appName+sLineBreak+'Version: '+appVers+sLineBreak+sLineBreak+
             'Build: '+appBuild+sLineBreak+sLineBreak+rsContact+': '+mymail,
              mtInformation,[mbOK], 0);
end;

{http://www.joerg-buchwitz.de/temp/googlemapssyntax.htm
 https://www.google.de/maps?q=48.235367,10.0944453&z=13&om=0 }

function URLGMap(lati, longi: string): string; {URL for coordinates in Google Maps}
begin
  result:=gmapURL+'?q='+lati+','+longi+'&z='+
                        gzoom+'&t=h&om=0';         {&t=k: Sat, &t=h: hybrid}
end;

{Entfernung zwischen zwei Koordinaten in m
 siehe Haversine formula, Erdradius: 6,371km abh. von Breitengrad
 https://rechneronline.de/erdradius/
 6365.692 optimiert für 50 Breitengrad und 60m Höhe

 D:\Flight_Log_data\_Eigene\YTH\3\FlightLog2019-07-01\Telemetry_00002.csv
 seit Update auf Lazarus 2.0.4 unerwartete Fehlrechnung mit result NaN:
                    lat1     lon1     lat2      lon2
Test-3564 : 0.1 von 48.86739 9.366312 48.86739  9.366313
Test-3565 : Nan von 48.86739 9.366313 48.86739  9.366313
Test-3566 : 0.1 von 48.86739 9.366313 48.86739  9.366315
Test-3567 : Nan von 48.86739 9.366315 48.86739  9.366315
Test-3568 : 0.5 von 48.86739 9.366315 48.867386 9.366317
}
function DeltaKoord(lat1, lon1, lat2, lon2: double): double;
begin
  result:=0;
  try
    result:=6365692*arccos(sin(lat1*pi/180)*sin(lat2*pi/180)+
            cos(lat1*pi/180)*cos(lat2*pi/180)*cos((lon1-lon2)*pi/180));
    if IsNan(result) or                            {Fehler in Formel ?}
       (result>30000) or   {> 30km --> unplausible Werte identifizieren}
       (result<0.005) then                         {Fehler reduzieren, Glättung}
      result:=0;
  except
  end;
end;

(******************************************************************************)

procedure TForm1.FormCreate(Sender: TObject);      {Initialization}
begin
  Form1.Caption:=appname+tab1+appvers+' ('+appbuild+')';
  btnOpen.Caption:=capOpen;
  btnOpen.Hint:=hntOpen;
  btnClose.Caption:=capClose;
  btnClose.Hint:=hntClose;
  cbTrkpt.Caption:=capTrkpt;
  cbTrkpt.Hint:=hntTrkpt;
  speRate.Hint:=hntRate;
  lblRate.Caption:=capRate;
  lblRate.Hint:=hntRate;

  MetaGrid.Hint:=hntMetaGrid;
  POIGrid.Hint:=hntPOIGrid;
  WPGrid.Hint:=hntWPGrid;
  WPGrid.Tag:=0;
  StatusBar1.Panels[1].Text:='.GPX';
  WPgrid.Cells[0,0]:='#';
  WPgrid.Cells[1,0]:=lat;
  WPgrid.Cells[2,0]:=lon;
  WPgrid.Cells[3,0]:=alt;
  WPgrid.Cells[4,0]:=speed;
  WPgrid.Cells[5,0]:=yaw;
  WPgrid.Cells[6,0]:=lastyaw;
  WPgrid.Cells[7,0]:=cont;
  WPgrid.Cells[8,0]:=followPOI;
  WPgrid.Cells[9,0]:=follow;
  WPgrid.Cells[10,0]:=actions;
  WPgrid.Cells[11,0]:=hdDistance;
  WPgrid.Cells[12,0]:=hdAscent;
  WPgrid.Cells[13,0]:=hdAddtrkpt;
  MetaGrid.Cells[0,0]:=hdParamter;
  MetaGrid.Cells[1,0]:=hdValue;
  POIgrid.Cells[0,0]:=hdParamter;
  POIgrid.Cells[1,0]:=hdValue;
end;

procedure TForm1.FormDblClick(Sender: TObject);    {Double click for About box}
begin
  ShowAbout;
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if key=vk_F5 then
    OpenPlanFile;;                                 {Reload}
end;

procedure TForm1.MetaGridKeyUp(Sender: TObject; var Key: Word;
                               Shift: TShiftState);
begin
  if (key=vk_c) and
     (ssCtrl in Shift) then
    MetaGrid.CopyToClipboard(false);               {Ctrl+C copy to clipboard}
end;

procedure TForm1.POIgridDblClick(Sender: TObject); {POI anzeigen}
var i: integer;
    lati, loni: string;
begin
  lati:='';
  loni:='';
  for i:=1 to POIgrid.RowCount-1 do begin
    if POIgrid.Cells[0, i]=lat then
      lati:=POIgrid.Cells[1, i];
    if POIgrid.Cells[0, i]=lon then
      loni:=POIgrid.Cells[1, i];
    if (lati<>'') and (loni<>'') then begin
      OpenURL(URLGMap(lati, loni));
      lati:='';
      loni:='';
    end;
  end;
end;

procedure TForm1.POIgridKeyUp(Sender: TObject; var Key: Word;
                               Shift: TShiftState);
begin
  if (key=vk_c) and
     (ssCtrl in Shift) then
    POIGrid.CopyToClipboard(false);                 {Ctrl+C copy to clipboard}
end;

procedure TForm1.StatusBar1DblClick(Sender: TObject);  {Open File Explorer}
begin
  OpenDocument(ExtractFileDir(OpenDialog1.FileName));
end;

procedure TForm1.WPgridDblClick(Sender: TObject); {Open Google Maps}
begin
  if WPGrid.Tag>0 then                            {Line number in data}
    OpenURL(URLGMap(WPgrid.Cells[1, WPGrid.Tag], WPgrid.Cells[2, WPGrid.Tag]));
end;

procedure TForm1.WPgridKeyUp(Sender: TObject; var Key: Word;
                             Shift: TShiftState);
begin
  if (key=vk_c) and
     (ssCtrl in Shift) then
    WPGrid.CopyToClipboard(false);                 {Ctrl+C copy to clipboard}
end;

procedure TForm1.WPgridSelection(Sender: TObject; aCol, aRow: Integer);
begin
  WPGrid.Tag:=aRow;                                {store the Selection for onclick}
end;

procedure TForm1.btnCloseClick(Sender: TObject);
begin
  Form1.Close;
end;

procedure TForm1.OpenPlanFile;                     {Analyze one JSON file}
var inf: TFileStream;
    j0, j1, j2, j3, j4, j5: TJsonData;             {4 level}
    i, k, numt, zhl: integer;
    GPXlist, WPlist: TStringList;
    lati, longi, alti, nme, anafi, swert: string;
    fwert, lat01, lon01, lat02, lon02, alt01, alt02, hdelta: double;
    tme: TDateTime;

  procedure NeueZeile(ogrid: TStringGrid; pname, pwert: string);
  begin
    oGrid.RowCount:=oGrid.RowCount+1;
    oGrid.Cells[0, oGrid.RowCount-1]:=pname;
    oGrid.Cells[1, oGrid.RowCount-1]:=pwert;
  end;

begin
  StatusBar1.Panels[2].Text:=ExtractFileName(OpenDialog1.FileName);
  Form1.Caption:=appname+tab1+appvers+' ('+appbuild+')'+tab4+
                 StatusBar1.Panels[2].Text;
  MetaGrid.RowCount:=1;
  POIgrid.RowCount:=1;
  WPgrid.RowCount:=1;
  WPGrid.Tag:=0;                    {Reset line number}
  lat01:=0;
  lon01:=0;
  alt01:=0;
  zhl:=0;
  inf:=TFileStream.Create(OpenDialog1.FileName, fmOpenRead or fmShareDenyWrite);
  Screen.Cursor:=crHourGlass;
  WPlist:=TStringList.Create;
  GPXlist:=TStringList.Create;
  GPXlist.Add(xmlvers);
  GPXlist.Add(gpxvers);
  GPXlist.Add('<metadata>');
  try
    j0:=GetJson(inf);               {load whole JSON file, level 0, Metadata}
    try
      swert:=j0.FindPath(title).AsString;
      NeueZeile(MetaGrid, title, swert);
      GPXlist.Add(tab2+'<'+namtag+swert+'</'+namtag);

      swert:=j0.FindPath(vers).AsString;
      NeueZeile(MetaGrid, vers, swert);
      GPXlist.Add(tab2+'<desc>'+vers+tab1+swert+'</desc>');

      tme:=UNIXtoDateTime(j0.FindPath(dt).AsInt64 div 1000);
      NeueZeile(MetaGrid, dt, FormatDateTime(ymd+tab1+hns, tme));

      anafi:=j0.FindPath(prod).AsString;
      NeueZeile(MetaGrid, prod, anafi);
      swert:=j0.FindPath(UUID).AsString;
      NeueZeile(MetaGrid, UUID, swert);
      fwert:=j0.FindPath(zoom).AsFloat;
      NeueZeile(MetaGrid, zoom, FormatFloat(frmZahl, fwert));
      fwert:=j0.FindPath(rota).AsFloat;
      NeueZeile(MetaGrid, rota, FormatFloat(frmZahl, fwert));
      fwert:=j0.FindPath(tilt).AsFloat;
      NeueZeile(MetaGrid, tilt, FormatFloat(frmZahl, fwert));
      swert:=j0.FindPath(maptyp).AsString;
      NeueZeile(MetaGrid, maptyp, swert);
      swert:=j0.FindPath(pca).AsString;
      NeueZeile(MetaGrid, pca, swert);
      swert:=j0.FindPath(dirt).AsString;
      NeueZeile(MetaGrid, dirt, swert);
    except
      StatusBar1.Panels[1].Text:='E:meta';
    end;
    GPXlist.Add('</metadata>');

    j1:=j0.FindPath(plan);                       {Next level 'plan'}
    if j1<>nil then begin
      try
        j2:=j1.FindPath(takeoff);                {Node 'takeoff'}
        if j2<>nil then begin
          for i:=0 to j2.Count-1 do begin
            Neuezeile(POIgrid, upCase(takeoff)+tab1+IntToStr(i+1), strich);
            j3:=j2.Items[i];
            if j3<>nil then begin
              swert:=j3.FindPath(typ).AsString;
              NeueZeile(POIgrid, typ, swert);
              swert:=j3.FindPath(camID).AsString;
              NeueZeile(POIgrid, camID, swert);
              swert:=j3.FindPath(res).AsString;
              NeueZeile(POIgrid, res, swert);
              swert:=j3.FindPath(fps).AsString;
              NeueZeile(POIgrid, fps, swert);
              NeueZeile(POIgrid, '', '');
            end;
          end;
        end;
      except
        StatusBar1.Panels[1].Text:='E:to';
      end;

      try
        j2:=j1.FindPath(poi);                    {Node 'POI'}
        if j2<>nil then begin
          for i:=0 to j2.Count-1 do begin
            NeueZeile(POIgrid, '', '');
            nme:=upCase(poi)+tab1+IntToStr(i+1);
            NeueZeile(POIgrid, nme, strich);
            j3:=j2.Items[i];
            if j3<>nil then begin
              fwert:=j3.FindPath(lat).AsFloat;
              lati:=FormatFloat(frmCoord, fwert);
              lati:=StringReplace(lati, ',', '.', []);
              NeueZeile(POIgrid, lat, lati);
              fwert:=j3.FindPath(lon).AsFloat;
              longi:=FormatFloat(frmCoord, fwert);
              longi:=StringReplace(longi, ',', '.', []);
              NeueZeile(POIgrid, lon, longi);
              alti:=j3.FindPath(alt).AsString;
              NeueZeile(POIgrid, alt, alti);
              swert:=j3.FindPath(colr).AsString;
              NeueZeile(POIgrid, colr, swert);
              alti:=StringReplace(alti, ',', '.', []);
              gpxlist.Add(wpttag+GPXlat+lati+GPXlon+longi+'"> <ele>'+alti+
                          '</ele> <time>'+FormatDateTime(ymd, tme)+
                          'T'+FormatDateTime(hns, tme)+
                          'Z</time> <'+namtag+nme+'</'+namtag+GPXet1);
            end;
          end;
        end;
      except
        StatusBar1.Panels[1].Text:='E:poi';
      end;

      GPXlist.Add('<trk>');
      GPXlist.Add(tab2+'<trkseg>');
      GPXlist.Add(tab2+'<'+namtag+Anafi+'</'+namtag);

      try
        j2:=j1.FindPath(wp);                     {Node 'Waypoints'}
        if j2<>nil then begin
          StatusBar1.Panels[0].Text:=IntToStr(j2.Count);
          for i:=0 to j2.Count-1 do begin
            j3:=j2.Items[i];
            if j3<>nil then begin
              WPgrid.RowCount:=WPGrid.RowCount+1;
              WPGrid.Cells[0, WPGrid.RowCount-1]:=IntToStr(i+1);

              lat02:=j3.FindPath(lat).AsFloat;
              lati:=FormatFloat(frmCoord, lat02);
              lon02:=j3.FindPath(lon).AsFloat;
              longi:=FormatFloat(frmCoord, lon02);
              alt02:=j3.FindPath(alt).AsFloat;
              alti:=FormatFloat(frmKurz, alt02);
              lati:=StringReplace(lati, ',', '.', []);
              longi:=StringReplace(longi, ',', '.', []);

              WPGrid.Cells[1, WPGrid.RowCount-1]:=lati;
              WPGrid.Cells[2, WPGrid.RowCount-1]:=longi;
              WPGrid.Cells[3, WPGrid.RowCount-1]:=alti;
              swert:=j3.FindPath(speed).AsString;
              WPGrid.Cells[4, WPGrid.RowCount-1]:=swert;
              fwert:=j3.FindPath(yaw).AsFloat;
              WPGrid.Cells[5, WPGrid.RowCount-1]:=FormatFloat(frmZahl, fwert);
              fwert:=j3.FindPath(lastyaw).AsFloat;
              WPGrid.Cells[6, WPGrid.RowCount-1]:=FormatFloat(frmZahl, fwert);
              swert:=j3.FindPath(cont).AsString;
              WPGrid.Cells[7, WPGrid.RowCount-1]:=swert;
              swert:=j3.FindPath(followPOI).AsString;
              if j3.FindPath('test')<>nil then
                swert:=j3.FindPath('test').AsString;
              WPGrid.Cells[8, WPGrid.RowCount-1]:=swert;
              swert:=j3.FindPath(follow).AsString;
              WPGrid.Cells[9, WPGrid.RowCount-1]:=swert;

              if (lat01=0) and (lon01=0) then begin             {List Delta}
                for k:=11 to 13 do
                  WPGrid.Cells[k, WPGrid.RowCount-1]:=plh;
              end else begin
                fwert:=DeltaKoord(lat01, lon01, lat02, lon02);  {Distance}
                WPGrid.Cells[11, WPGrid.RowCount-1]:=FormatFloat(frmKurz, fwert);
                WPGrid.Cells[12, WPGrid.RowCount-1]:=FormatFloat(frmKurz, alt02-alt01);

 {Insert additional trackpoints, linear interplated. Rate according settings and
  sqrt(delta_altitude²+distance²).}
                hdelta:=alt02-alt01;
                numt:=round(sqrt((hdelta*hdelta)+(fwert*fwert))) div speRate.Value;
                if numt>1 then begin               {Create additional trkpt}
                  WPGrid.Cells[13, WPGrid.RowCount-1]:=IntToStr(numt-1);
                  if cbTrkpt.Checked then begin
                    for k:=1 to numt-1 do begin
                      swert:=StringReplace(tab4+'<trkpt'+GPXlat+
                             FormatFloat(frmCoord, ((lat02-lat01)/numt*k)+lat01)+
                             GPXlon+
                             FormatFloat(frmCoord, ((lon02-lon01)/numt*k)+lon01)+
                             '"> <ele>'+
                             FormatFloat(frmKurz, ((hdelta)/numt*k)+alt01)+
                             '</ele> </trkpt>',',', '.', [rfReplaceAll]);
                      GPXlist.Add(swert);
                      inc(zhl);
                    end;
                  end;
                end else
                  WPGrid.Cells[13, WPGrid.RowCount-1]:='0';
              end;
              GPXlist.Add(tab4+'<trkpt'+GPXlat+lati+GPXlon+longi+
                               '"> <ele>'+alti+'</ele> </trkpt>');
              WPlist.Add(wpttag+GPXlat+lati+GPXlon+longi+'"> <ele>'+
                         alti+'</ele> <'+namtag+'WP'+
                         IntToStr(WPgrid.RowCount-1)+'</'+namtag+GPXet1);
              inc(zhl);

              j4:=j3.FindPath(actions);
              if j4<>nil then begin                {Actions available}
                swert:='';
                for k:=0 to j4.Count-1 do begin
                  j5:=j4.Items[k];
                  if j5<>nil then begin
                    if j5.FindPath(typ)<>nil then begin
                      nme:=j5.FindPath(typ).AsString;
                      if k=0 then
                        swert:=nme
                      else
                        swert:=swert+'|'+nme;
                      if j5.FindPath(angle)<>nil then begin
                        nme:=j5.FindPath(angle).AsString;
                        swert:=swert+'/'+angle+': '+nme;
                      end;
                      if j5.FindPath(speed)<>nil then begin
                        nme:=j5.FindPath(speed).AsString;
                        swert:=swert+'/'+speed+': '+nme;
                      end;
                    end;
                  end;
                end;
                WPGrid.Cells[10, WPGrid.RowCount-1]:=swert;
              end;
              lat01:=lat02;
              lon01:=lon02;
              alt01:=alt02;
            end;
          end;
        end;
        if cbTrkpt.Checked then
          StatusBar1.Panels[1].Text:=IntToStr(zhl);
      except
        StatusBar1.Panels[1].Text:='E:wpt';
      end;

      GPXlist.Add(tab2+'</trkseg>');
      GPXlist.Add('</trk>');
      if cbTrkpt.Checked then begin
        for k:=0 to WPlist.Count-1 do
          GPXlist.Add(WPlist[k]);
      end;
    end;
    GPXlist.Add('</gpx>');
    wpGrid.AutoSizeColumns;
    MetaGrid.AutoSizeColumns;
    POIGrid.AutoSizeColumns;
  finally
    Screen.Cursor:=crDefault;
    swert:=ChangeFileExt(OpenDialog1.FileName, '.gpx');
    GPXlist.SaveToFile(swert);
    StatusBar1.Panels[2].Text:=swert;
    GPXlist.Free;
    WPlist.Free;
    j0.Free;
  end;
end;

procedure TForm1.btnOpenClick(Sender: TObject);    {Open one JSON flight plan file}
begin
  if OpenDialog1.Execute then
    OpenPlanFile;
end;

end.


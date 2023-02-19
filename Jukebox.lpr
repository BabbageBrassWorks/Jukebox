program Jukebox;

{$mode objfpc}{$H+}

{ Example 12 Web Server                                                        }
{                                                                              }
{  This example demonstrates how to create a simple web server using the HTTP  }
{  listener class. Ultibo includes both client and server classes for HTTP     }
{  which can be used to interact with your devices in numerous ways.           }
{                                                                              }
{  To compile the example select Run, Compile (or Run, Build) from the menu.   }
{                                                                              }
{  Once compiled copy the kernel.img file to an SD card along with the firmware}
{  files and use it to boot your Raspberry Pi.                                 }
{                                                                              }
{  Raspberry Pi A/B/A+/B+/Zero/ZeroW version                                   }
{   What's the difference? See Project, Project Options, Config and Target.    }

{Declare some units used by this example.}
uses
  {$IFDEF RPI}
  RaspberryPi,
  BCM2835,
  BCM2708,
  {$ENDIF}
  {$IFDEF RPI3}
  RaspberryPi3,
  BCM2837,
  BCM2710,
  {$ENDIF}
  {$IFDEF RPI4}
  RaspberryPi4,
  BCM2838,
  BCM2711,
  {$ENDIF}
  GlobalConfig,
  GlobalConst,
  GlobalTypes,
  Platform,
  Threads,
  Console,
  Framebuffer,
  GraphicsConsole,
  dispmanx,
  ubitmap,
  VC4,
  MMC,             {Include the MMC/SD unit for access to the SD card}
  SysUtils,
  HTTP,            {Include the HTTP unit for the server classes}
  Winsock2,        {Include the Winsock2 unit so we can get the IP address}
  FileSystem,      {Include the File system so we have some files to serve up}
  FATFS,           {Plus the FAT file system unit}
  SMSC95XX,        {And the drivers for the Raspberry Pi network adapter}
  USBCDCEthernet,
  DWCOTG,          {As well as the driver for the Raspberry Pi USB host}
  Shell,           {Add the Shell unit just for some fun}
  ShellFilesystem, {Plus the File system shell commands}
  ShellUSB,        {Add the USB shell commands as well}
  RemoteShell,     {And the RemoteShell unit so we can Telnet to our Pi}
  Player,
  uTFTP,
  uFTP,
  WebStatus,
  UltiboUtils,  {Include Ultibo utils for some command line manipulation}
  Ultibo;


{A window handle and some others.}
var
 IPAddress:String;
 WindowHandle:TWindowHandle;
 HTTPListener:THTTPListener;
 HTTPListener1:THTTPListener;
 HTTPFolder:THTTPFolder;
 Winsock2TCPClient:TWinsock2TCPClient;
 FTPServer : TFTPserver;
 uc : TUserCred;
 AudioThread: TAudioThread;
 VideoThread: TVideoThread;
 title:string;


begin
 //Enable Console Autocreate

 //CONSOLE_DEFAULT_BORDERWIDTH:=0;
 ConsoleFramebufferDeviceAdd(FramebufferDeviceGetDefault);
 WindowHandle := ConsoleWindowCreate(ConsoleDeviceGetDefault, CONSOLE_POSITION_FULLSCREEN, True);


 {Output the message}
 ConsoleWindowWriteLn(WindowHandle,'Welcome to Jukebox');
 ConsoleWindowWriteLn(WindowHandle,'');

 {Create a Winsock2TCPClient so that we can get some local information}
 Winsock2TCPClient:=TWinsock2TCPClient.Create;

 {Print our host name on the screen}
 ConsoleWindowWriteLn(WindowHandle,'Host name is ' + Winsock2TCPClient.LocalHost);

 {Get our local IP address which may be invalid at this point}
 IPAddress:=Winsock2TCPClient.LocalAddress;

 {Check the local IP address}
 if (IPAddress = '') or (IPAddress = '0.0.0.0') or (IPAddress = '255.255.255.255') then
  begin
   ConsoleWindowWriteLn(WindowHandle,'IP address is ' + IPAddress);
   ConsoleWindowWriteLn(WindowHandle,'Waiting for a valid IP address, make sure the network is connected');

   {Wait until we have an IP address}
   while (IPAddress = '') or (IPAddress = '0.0.0.0') or (IPAddress = '255.255.255.255') do
    begin
     {Sleep a bit}
     Sleep(100);

     {Get the address again}
     IPAddress:=Winsock2TCPClient.LocalAddress;
    end;
  end;

 {Print our IP address on the screen}
 ConsoleWindowWriteLn(WindowHandle,'IP address is ' + IPAddress);
 ConsoleWindowWriteLn(WindowHandle,'');

 {We may need to wait a couple of seconds for drives to be ready}
 if not DirectoryExists('C:\') then
  begin
   ConsoleWindowWriteLn(WindowHandle,'Waiting for drive C:\');
   
   {Wait for C:\ drive}
   while not DirectoryExists('C:\') do
    begin
     {Sleep for a moment}
     Sleep(100);
    end;
  end;

 {Let's create a www folder on C:\ for our web server}
 if DirectoryExists('C:\') and not(DirectoryExists('C:\www')) then
  begin
   {Create the folder, if you want to create it on your SD card first and copy
    some files into it then the example will be able to serve them up to your browser.}
   ConsoleWindowWriteLn(WindowHandle,'Creating folder C:\www');
   CreateDir('C:\www');
  end;

 {webstatus page}
 //HTTPListener1:=THTTPListener.Create;
 //HTTPListener1.Active:=True;
 //HTTPListener1.BoundPort:=1000;

 //WebStatusRegister(HTTPListener1,'','',True);


 {First create the HTTP listener}
 ConsoleWindowWriteLn(WindowHandle,'Creating HTTP listener');
 HTTPListener:=THTTPListener.Create;

 {And set it to active so it listens}
 ConsoleWindowWriteLn(WindowHandle,'Setting listener to active');
 HTTPListener.Active:=True;

 {We need to create a HTTP folder object which will define the folder to serve}
 ConsoleWindowWriteLn(WindowHandle,'Creating HTTP folder / for C:\www');
 HTTPFolder:=THTTPFolder.Create;
 HTTPFolder.Name:='/';
 HTTPFolder.Folder:='C:\www';

 {And register it with the HTTP listener}
 ConsoleWindowWriteLn(WindowHandle,'Registering HTTP folder');
 HTTPListener.RegisterDocument('',HTTPFolder);


 {Should be ok to go, report the URL}
 ConsoleWindowWriteLn(WindowHandle,'');
 ConsoleWindowWriteLn(WindowHandle,'Web Server ready, point your browser to http://' + Winsock2TCPClient.LocalAddress + '/');

 {Free the Winsock2TCPClient object}
 Winsock2TCPClient.Free;

 //ConsoleWindowWriteLn(WindowHandle,'Loading wallpaper');

 // create FTP Server
 FTPServer := TFTPServer.Create;
 // add user accounts and options
 uc := FTPServer.AddUser ('admin', 'admin', 'C:\www\');
 uc.Options := [foCanAddFolder, foCanChangeFolder, foCanDelete, foCanDeleteFolder, foRebootOnImg];
 uc := FTPServer.AddUser ('user', '', 'C:\www\');
 uc.Options := [foRebootOnImg];
 uc := FTPServer.AddUser ('anonymous', '', 'C:\www\');
 uc.Options := [foRebootOnImg];
 // use standard FTP port
 FTPServer.BoundPort := 21;
 // set it running
 FTPServer.Active := true;


 BCMHostInit;

  AudioThread := TAudioThread.Create('C:\www\music\forest.wav', True);
  VideoThread := TVideoThread.Create('C:\www\music\forest.h264', True);

  // Start audio thread (Video thread starts immediately)
  AudioThread.Start;

  title := 'forest';

  while True do
    begin
      sleep(5000);
    end;

  BCMHostDeinit;

  ConsoleWindowWriteLn(WindowHandle, 'Halted.');

 {Halt the thread, the web server will still be available}
 ThreadHalt(0);
end.


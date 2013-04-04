YBWebcam
========

This is my personal project for checking out what my cat is doing while she is in my room and I'm in the living room watching tv.

In case if anyone's curious, she's just sleeping most of the time.

To Use:

1. Build and run this project in 2 iDevices.
2. Select the device you wish to use as webcam
3. Video streaming starts

Basic flow of this project:

1. Set up TCP server
2. Use NSNetService to publish my services
3. Use NSNetServiceBrowser to look for services 
4. Choose the service to connect to
5. AVCaptureSession starts running and display image through iPhone's camera

There are probably bugs here and there, but it does what I need it to do so I'm content for now XDDDDD

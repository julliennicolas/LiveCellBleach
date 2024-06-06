// Version 240605
// Nicolas Jullien - NeuroCyto team - INP UMR7051 - Aix Marseille Universié CNRS
// nicolas.jullien@univ-amu.fr

// This macro is used to document and analyse bleaching on live cell imaging movies (ie stacks)
// it is provided "as this" with no guarantee of relevant results!


function NJ_getTitleWithoutExtension(s) { 
// returns a file name without the extension (even if there's another '.' in the file name)
a=split(s,'.');
a=Array.trim(a,a.length-1);
return String.join(a,'.');
}

function NJ_Add2Stack(thisPic,thisStack,thisLegend){
	/
	/// TO DO (?)
}

function NJ_scaleBar(){
	getPixelSize(unit, pixelWidth, pixelHeight);
	scale = 1/pixelWidth; // pixel/µ
	getDimensions(nwidth, nheight, nchannels, nslices, nframes);
	// we'll use a scale representing about 1/20 of the width and in multiples of 5.
	sb=(floor(nwidth/20/scale/5)+1)*5;
	fontSize=floor(nheight/35);
	tickness=fontSize/4;
	run("Scale Bar...", "width="+sb+"  thickness="+tickness+" font="+fontSize+" color=White background=None location=[Lower Right] horizontal bold overlay");
}

// Assign folders
setOption("JFileChooser", true); // Change to Java file browser instead of Finder, but still displays window title 

zzinputDir=getDirectory("Select Image folder"); 
zzmyList=getFileList(zzinputDir);

zzoutputDir=getDirectory("Select OUT folder");


// other variables and settings


// font size calculated below according to the size of the thumbnails / images in which they will be used

 // to be sure that images will be processed with black as background (signal is white)
setBackgroundColor(0,0,0);
setOption("BlackBackground",true);
//  but you also have to redefine each threshold call! See below...

//

Dialog.create("Options");
Dialog.addNumber("Selection size (let 0 for entire image)", 0);
Dialog.addChoice("autocenter", newArray("manual","autocenter","maximum signal area"));
Dialog.addChoice("Make gallery with...", newArray("Original images","Background substracted images"));
Dialog.addCheckbox("Compensate bleaching in gallery", false);
Dialog.addCheckbox("Save AVI", true);
Dialog.addCheckbox("Debug Mode", false);
Dialog.show();
zzSelectionSize= Dialog.getNumber();
zzSelectionType=Dialog.getChoice();
zzImageForGalery=Dialog.getChoice();
zzOptionCompensateBleaching=Dialog.getCheckbox();
zzSaveAVI=Dialog.getCheckbox();
zzDebugMode=Dialog.getCheckbox();


/// ***************************

if(!zzDebugMode){
setBatchMode("hide");
}

for (i = 0; i < zzmyList.length ; i++) {
run("Bio-Formats", "open=["+zzinputDir+zzmyList[i]+"] color_mode=Colorized rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
getDimensions(nwidth, nheight, nchannels, nslices, nframes);
if(i==0){	
	myFontSize=floor(nwidth/25);
	setFont("SansSerif", myFontSize);
	setColor(255, 255, 255);
}

exportStack="exportStack";
this_title= NJ_getTitleWithoutExtension(getTitle());
// to return to the stack later in the script
mainStack=getImageID();


// If you want a selection
if(zzSelectionSize!=0){
	_x=Math.floor(nwidth/2-zzSelectionSize/2);
	_y=Math.floor(nheight/2-zzSelectionSize/2);
	run("Specify...", "width="+zzSelectionSize+" height="+zzSelectionSize+" x="+_x+" y="+_y+" slice=1");
	if(zzSelectionType=="manual"){
		setBatchMode("show");
		waitForUser("Déplacer la sélection sur la région d'intêret et cliquer OK");
	}
	run("Crop");
	this_title="ROI_"+zzSelectionType+"_"+this_title;
}



//
NJ_scaleBar();

getDimensions(nwidth, nheight, nchannels, nslices, nframes);
//
if(zzSaveAVI){
run("Enhance Contrast", "saturated=1");
run("7 Orange Hot ");
//record a short film
// we set a speed according to the number of frames so that it doesn't last too long: 20 sec total
frameSpeed=floor(nframes/20);
run("AVI... ", "compression=JPEG frame="+frameSpeed+" save=["+zzoutputDir+this_title+"("+frameSpeed+"fps).avi]");
}

if(zzDebugMode){
	waitForUser("Line 114");
}

roiManager("reset"); // to find out which index to call after

// the first frame selects everything that is saturated
selectImage(mainStack);
run("Duplicate...", "duplicate frames=1");
myPic=getImageID();
Image.copy;

newImage(exportStack, "8-bit", nwidth, nheight, 1);
Image.paste(0,0); // in the first exportstack slide to illustrate
drawString("1st frame=",myFontSize,myFontSize+4);
selectImage(myPic);
// owe'll do a little blur first to get a little wider (?)
run("Gaussian Blur...", "sigma=2");
// then threshold on what is almost saturated
setThreshold(65000, 65535);
setOption("BlackBackground", true);
run("Create Mask");

//--- need to make a function of the block belows
Image.copy;
selectWindow("exportStack");
run("Add Slice");
Image.paste(0,0); // the mask of what is saturated in the export stack
drawString("Saturated on 1st frame",myFontSize,myFontSize+4);
//--
selectImage(myPic);
run("Create Selection");
run("Make Inverse");
roiManager("Add"); // so ROi index 0 => everything not saturated

if(zzDebugMode){
	waitForUser("Line 149");
}

// **************************************************

// Now we go to the last image and take the mask of everything above the BDF.
selectImage(mainStack);
run("Duplicate...", "duplicate frames="+nSlices);
myPic=getImageID();
//--- need to make a function of the block belows
Image.copy;
selectWindow("exportStack");
run("Add Slice");
Image.paste(0,0);
drawString("Last frame",myFontSize,myFontSize+4); 
//--
selectImage(myPic);
run("Duplicate...", " "); // need to duplicate the image to be able to return to it after measuring the background on the thresholded image!
setAutoThreshold("Triangle dark no-reset");
setOption("BlackBackground", true);
run("Create Mask");
run("Create Selection");
roiManager("Add"); // ROI index 1 = everything above the bdf
//---- need to make a function of the block belows
Image.copy;
selectWindow("exportStack");
run("Add Slice");
Image.paste(0,0);
drawString("Measurment mask",myFontSize,myFontSize+4); 
//--
//
// global mode measurement on this last stack frame (no more bdf)
selectImage(myPic); // =the last frame of the film
roiManager("Select", 1);
// the reverse selection corresponds essentially to the background
run("Make Inverse");
// mean and deviation are measured
run("Set Measurements...", "mean standard redirect=None decimal=9");
run("Clear Results");
run("Measure");
bkground=round(getResult("Mean")+0.5*getResult("StdDev")); 


if(zzDebugMode){
	waitForUser("Line 193");
}

// ******************************************************

// on revient au stack
selectImage(mainStack);
run("Select None"); // normally there's nothing selected here but ...
run("Duplicate...", "duplicate"); // the full stack
run("Subtract...", "value="+bkground+" stack");
NoBgStack=getImageID(); // we keep the stack ID without background
getMinAndMax(mmin, mmax);
run("Enhance Contrast", "saturated=1");
//waitForUser("image no backgroud");

//--
Image.copy;
selectWindow("exportStack");
run("Add Slice");
Image.paste(0,0);
drawString("Subs. bg. ="+bkground,myFontSize,myFontSize+4);
//--
// ****
// we'll illustrate with 8 images from the stack (Main ou NoBg --> determined by the user in the dialog (see above)

if(zzImageForGalery=="Original images"){
	selectImage(mainStack);
	}
	else{
		selectImage(NoBgStack);
}

UsedStack=getImageID(); // to return to it in the loop below
Stack.setFrame(1);
run("Enhance Contrast", "saturated=1");
// key frames are selected according to the total number of frames
getDimensions(zzwidth, zzheight, zzchannels, zzslices, zzframes);
frameStep=floor(zzframes/8);
for (j = 0; j < zzframes; j+=frameStep) {
	selectImage(UsedStack);
	Stack.setFrame(j);
	if(zzOptionCompensateBleaching){
		run("Enhance Contrast", "saturated=1"); // to show all thumbnails, compensating for bleaching
	}
	drawString("frame="+j,myFontSize,myFontSize+4);
	Image.copy;
	selectWindow("exportStack");
	run("Add Slice");
	Image.paste(0,0);
	
	if(zzDebugMode){
	waitForUser("Line 239 - Loop j="+j);
}
} // next for j
// ****

// *****
selectImage(NoBgStack);
// we select the intersection of what is not saturated and what is above the bdf
roiManager("Select", newArray(0,1));
roiManager("AND");
run("Set Measurements...", "mean redirect=None decimal=9");
run("Clear Results");
run("Measure Stack...");
selectWindow("Results");
saveAs("Results", zzoutputDir+this_title+"_Zprofile.csv");


// ******
selectWindow("exportStack");
// we'll determine the export scale according to the image size we already have in nwidth
// Each thumbnail will be 500px wide. --> scale = 500 / nwidth (but we don't enlarge, so we take maxOf
getDimensions(zzwidth, zzheight, zzchannels, zzslices, zzframes);
exportScale=Math.max(500/zzwidth,1);
print("Make Montage...", "columns="+zzslices+" rows=1 scale="+exportScale); //DEBUG
run("Make Montage...", "columns="+zzslices+" rows=1 scale="+exportScale);
saveAs("Jpeg", zzoutputDir+this_title+"_montage.jpg");
run("Close All");
//i=10000 ; // DEBUG
} // next i
showMessage("DONE! :)");


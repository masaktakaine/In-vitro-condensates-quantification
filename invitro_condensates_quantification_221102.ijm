// In vitro condensates quantification
// author: Masak Takaine

// This FIJI macro allows automatic detection and analysis of fluorescent condensates observed in in vitro assay.
// As input, two channel image file that contains a pair of fluorescence (Ch #1) and bright field or phase contrast (Ch #2) microscopic images is required.
// This macro is optimized for images accuired by using a 100x objective lens.

macro "In_vitro_condensates_quantification" {

#@ String(label="Date of experiments, e.g., 2022-02-05") edate1
#@ File (label="Choose source Folder", style="directory") dirS1 
#@ File (label="Choose destination Folder", style="directory") dirD1
#@ String(label="Hide/Show the active image? The Show slows the analysis.", choices={"hide","show"}, style="radioButtonHorizontal") sbm

setBatchMode(sbm); // hides the active image, required ImageJ 1.48h or later
dirS = dirS1 + File.separator; // "File.separator" returns the file name separator character depending on the OS system used.
dirD = dirD1 + File.separator;

//setOption("ExpandableArrays", true);  // Enables/disables support for auto-expanding arrays, In ImageJ 1.53g or newer, arrays automatically expand in size as needed.
edate = " "+edate1; // Insert a blank to prevent automatic modification on Excel.

imagefilelist = getFileList(dirS);
date =newArray;
file_name = newArray; 	// An array to store filenames
raw_globalmeans = newArray;
raw_globalmedians = newArray;
raw_globalmodes = newArray;
raw_globalsds = newArray;

globalmeans = newArray;
globalmedians = newArray;
globalmodes = newArray;
globalsds = newArray;
thresholds = newArray;
particlenums = newArray;

dirBF = dirD + "/BF/";		//Create a folder for phase-contrast or biright-field images
File.makeDirectory(dirBF);				

dirGreen = dirD + "/green/";  //Create a folder for fluorescent images
File.makeDirectory(dirGreen);				

dirDR = dirD + "/Drawings/";  //Create a folder for mask images and ROI data
File.makeDirectory(dirDR);

dirCSV = dirD +"/" + edate1 + "_csv/";
File.makeDirectory(dirCSV);	  // Create a folder for csv files

for (i = 0; i < imagefilelist.length; i++) {
    currFile = dirS + imagefilelist[i];
    if((endsWith(currFile, ".nd2"))||(endsWith(currFile, ".oib"))||(endsWith(currFile, ".zvi"))) { // process if files ending with .oib or .nd2, or .zvi
		run("Bio-Formats Macro Extensions"); 
		Ext.openImagePlus(currFile)}
	else if ((endsWith(currFile, ".tif"))||(endsWith(currFile, ".tiff"))) {// process if files ending with .tif or .tiff (hyperstack files)
			open(currFile); 
		}

print("\\Clear"); 
title = getTitle();
// Remove the extension from the filename
title_s = replace(title, "\\.nd2", ""); 
title_s = replace(title_s, "\\.tif", "");
title_s = replace(title_s, "\\.tiff", "");

run("Split Channels");
c1 = "C1-" + title; // Channel #1：fluorescence image
c2 = "C2-" + title; // Channel #2：bright field/phase-contrast image

selectWindow(c2);
BFID = getImageID();
selectImage(BFID);
saveAs("Tiff", dirBF + title_s);
close();

selectWindow(c1);						
GRID = getImageID();
run("Grays");
saveAs("Tiff", dirGreen + title_s);

run("Duplicate...", "title=Temp"); //Duplicate and rename
selectWindow("Temp");
raw_globalmean = getValue("Mean raw");
raw_globalmedian = getValue("Median raw");
raw_globalmode = getValue("Mode raw");
raw_globalsd = getValue("StdDev raw");
run("Subtract Background...", "rolling=20 disable");
globalmean = getValue("Mean raw");
globalmedian = getValue("Median raw");
globalmode = getValue("Mode raw");
globalsd = getValue("StdDev raw");

// The intensity threshold is determined as the mean intensity plus 3 times the standard deviation of the image.
threshold = globalmean + 3*globalsd;

setThreshold(threshold, 65535, "raw");
setOption("BlackBackground", true);
run("Convert to Mask");
resetThreshold();

// Detection of condensates
run("Set Measurements...", "area mean min centroid shape integrated redirect=None decimal=3"); 
run("Analyze Particles...", "size=0.04-500 circularity=0.1-1.00 show=Masks exclude clear add");
//run("Analyze Particles...", "size=0.02-100 circularity=0.3-1.00 show=Outlines exclude clear add"); // outline
particlenums[i] = nResults;

selectImage(GRID);; // Superimpose ROIs on the original fluorescence image
roiManager("Show None");
roiManager("Show All");
run("Clear Results");
roiManager("Measure");

for(k=0; k<nResults; k++) {   // Activate and analyse a ROI one by one
 setResult("date",k,edate);
 setResult("file",k,title_s);
 setResult("gMean",k, globalmean);
 setResult("gMedian",k,globalmedian);
 setResult("gMode",k,globalmode);
 setResult("gSD",k,globalsd);
 setResult("threshold",k,threshold);				
}
saveAs("Results", dirCSV + title_s + ".csv");

selectWindow("Mask of Temp");
roiManager("Show None");
roiManager("Show All"); 	// Show all ROIs to save the ROIs as overlays
saveAs("Tiff", dirDR +title_s);
close();
run("Close");	
	run("Close All");
    run("Clear Results");						
	print("\\Clear");
	roiManager("reset");

date[i] = edate;
file_name[i] = title_s;	
raw_globalmeans[i] = raw_globalmean;					
raw_globalmedians[i] = raw_globalmedian;	
raw_globalmodes[i] = raw_globalmode;	
raw_globalsds[i] = raw_globalsd;	
globalmeans[i] = globalmean;
globalmedians[i] = globalmedian;	
globalmodes[i] = globalmode;	
globalsds[i] = globalsd;	
thresholds[i] = threshold;
//particlenums[i] = nResults;
}
Array.show("global_prams(row numbers)", date, file_name, raw_globalmeans, raw_globalmedians, raw_globalmodes, raw_globalsds,globalmeans, globalmedians, globalmodes, globalsds, thresholds,particlenums); //配列を独立したwindowに表示する、タイトルが(row numbers)で終わると最初の列が1から始まる行のインデックスになる												
    selectWindow("global_prams");
    saveAs("Results", dirD + edate1 + "_global_prams.csv"); 
 
	run("Close");	
    run("Clear Results");						// Reset Results window
	print("\\Clear"); 							// Reset Log window
	roiManager("reset");						// Reset ROI manager
	
	showMessage(" ", "<html>"+"<font size=+2>Process completed<br>");
}
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
dirD1 = dirD1 + File.separator;

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
particle_nums = newArray;

mean_areas = newArray();
//sd_areas = newArray();
mean_meanints = newArray();
//sd_meanints = newArray();
mean_intdens = newArray();
//sd_intdens = newArray();
sum_intdens = newArray();
mean_roundness = newArray();
mean_AR = newArray();
mean_circ = newArray();
mean_solidity = newArray();

dirD = dirD1 +"/"+ edate1 + "_output";
File.makeDirectory(dirD);

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
run("Clear Results");						// Reset Results window
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
//run("Analyze Particles...", "size=0.04-1 circularity=0.1-1.00 show=Masks exclude clear add");
run("Analyze Particles...", "size=0.04-500 circularity=0.1-1.00 show=Masks exclude clear add");
//run("Analyze Particles...", "size=0.02-100 circularity=0.3-1.00 show=Outlines exclude clear add"); // outline
particle_nums[i] = nResults;

if (nResults !=0) {  // if particles were detected
run("Clear Results");
selectImage(GRID);; // Superimpose ROIs on the original fluorescence image
roiManager("Show None");
roiManager("Show All");
roiManager("Measure");
//wait(100);
for(k=0; k<nResults; k++) {
 setResult("date",k,edate);
 setResult("file",k,title_s);
 setResult("gMean",k, globalmean);
 setResult("gMedian",k,globalmedian);
 setResult("gMode",k,globalmode);
 setResult("gSD",k,globalsd);
 setResult("threshold",k,threshold);		
}
// Because Table.getColumn() does not work in batch-mode ("hide"),
//the specified column in the Results table is obtained as an array by iterating getResult().
colArea = newArray();
colMean = newArray();
colIntDen = newArray();
colRound = newArray();
colAR = newArray();
colCirc = newArray();
colSolid = newArray();
for (p=0; p<nResults; p++){ 
	colArea[p] =getResult("Area", p);
	colMean[p] =getResult("Mean",p);
	colIntDen[p] = getResult("IntDen",p);
	colRound[p] = getResult("Round",p);
	colAR[p] = getResult("AR",p);
	colCirc[p] = getResult("Circ.",p);
	colSolid[p] = getResult("Solidity",p);
}
Array.getStatistics(colArea, min1, max1, mean1, stdDev1);
// Return min, max, mean and stdDev of the Area column to min1, max1, mean1 and stdDev1, respectively
Array.getStatistics(colMean, min2, max2, mean2, stdDev2);
Array.getStatistics(colIntDen, min3, max3, mean3, stdDev3);
Array.getStatistics(colRound, min4, max4, mean4, stdDev4);
Array.getStatistics(colAR, min5, max5, mean5, stdDev5);
Array.getStatistics(colCirc, min6, max6, mean6, stdDev6);
Array.getStatistics(colSolid, min7, max7, mean7, stdDev7);
saveAs("Results", dirCSV + title_s + ".csv");
} else{ // if no particels were detected
	run("Clear Results");
	setResult("Area", 0, "NaN");
	setResult("Mean", 0, "NaN");
	setResult("Min", 0, "NaN");
	setResult("Max", 0, "NaN");
	setResult("X", 0, "NaN");
	setResult("Y", 0, "NaN");
	setResult("Circ.", 0, "NaN");
	setResult("IntDen", 0, "NaN");
	setResult("RawIntDen", 0, "NaN");
	setResult("AR", 0, "NaN");
	setResult("Round", 0, "NaN");
	setResult("Solidity", 0, "NaN");
	setResult("date",0,edate);
 setResult("file",0,title_s);
 setResult("gMean",0, globalmean);
 setResult("gMedian",0,globalmedian);
 setResult("gMode",0,globalmode);
 setResult("gSD",0,globalsd);
 setResult("threshold",0,threshold);
 saveAs("Results", dirCSV + title_s + ".csv");
 wait(100);
}

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

if (particle_nums[i] !=0) {
mean_areas[i] = mean1;
mean_meanints[i] = mean2;
mean_intdens[i] = mean3;
sum_intdens[i] = particle_nums[i]*mean_intdens[i];
mean_roundness[i] = mean4;
mean_AR[i] = mean5;
mean_circ[i] = mean6;
mean_solidity[i] = mean7;
} else{
	mean_areas[i] = NaN;
	mean_meanints[i] = NaN;
	mean_intdens[i] = NaN;
	sum_intdens[i] = NaN;
	mean_roundness[i] = NaN;
	mean_AR[i] = NaN;
	mean_circ[i] = NaN;
mean_solidity[i] = NaN;
}
//particle_nums[i] = nResults;
}
// Show global parameters of the image in a new table.	
Array.show("global_prams(row numbers)", date, file_name, raw_globalmeans, raw_globalmedians,
raw_globalmodes, raw_globalsds,globalmeans, globalmedians, globalmodes,
globalsds, thresholds,particle_nums);
//run("Summarize");									
    selectWindow("global_prams");
    saveAs("Results", dirD +"/"+ edate1 + "_global_prams.csv");
    run("Close");
    
// Show statistics of the particles in a new table.	
Array.show("particle_stat(row numbers)", date, file_name,particle_nums, mean_areas,
mean_meanints, mean_intdens, sum_intdens, mean_roundness, mean_AR, mean_circ, mean_solidity);
	selectWindow("particle_stat");
    saveAs("Results", dirD +"/"+ edate1 + "_particle_stat.csv");
	run("Close");	
    run("Clear Results");						// Reset Results window
	print("\\Clear"); 							// Reset Log window
	roiManager("reset");						// Reset ROI manager
	run("Close All");
	run("Close All");
	showMessage(" ", "<html>"+"<font size=+2>Process completed<br>");
}
# In vitro condensates quantification, jython version
# author: Masak Takaine

# This FIJI macro allows automatic detection and analysis of fluorescent condensates observed in in vitro assay.
# As input, two channel image file that contains a pair of fluorescence (Ch #1) and bright field or phase contrast (Ch #2) microscopic images is required.
# This macro is optimized for images accuired by using a 100x objective lens.

#@ String(label="Date of experiments, e.g., 2022-02-05") edate1
#@ File (label="Choose source Folder", style="directory") dirS0 
#@ File (label="Choose destination Folder", style="directory") dirD0

from ij import IJ, ImagePlus, Prefs
from ij.process import ImageStatistics as IS
options = IS.MEAN | IS.AREA | IS.STD_DEV  # many others
from ij.gui import Roi
from ij.plugin.frame import RoiManager
from ij.measure import ResultsTable
from ij.plugin import ChannelSplitter as CS
from ij.plugin import RGBStackMerge, RGBStackConverter
import os
from os import path
from org.apache.commons.math3.stat.descriptive import DescriptiveStatistics as DSS

# Save the Result Table in csv format
def save_result_table(directory, filename, result_table):
    resultfile = os.path.join(directory, filename + ".csv") 
    result_table.saveAs(resultfile)

# Save the image file in tiff format
def save_image_as_tif(directory, filename, image):
    outputfile = os.path.join(directory, filename + ".tif")
    IJ.saveAs(image, "TIFF", outputfile) # 保存する画像、tiff形式、パスを指定

# Analyze the image of fluorescent condensates
def analyse_vitro_image(current_file_path):
	imp0 = IJ.openImage(current_file_path)
	filename = imp0.getTitle().split(".")[0] 
	cs = CS()
	image_list = cs.split(imp0)
	imp = image_list[0] # Channel #1：fluorescence image
	ch2 = image_list[1] # Channel #2：bright field/phase-contrast image
	
	imp2 = imp.duplicate()
	imp2.setTitle("mask")
	raw_globalmean = IJ.getValue(imp2, "Mean raw")
	raw_globalmedian = IJ.getValue(imp2, "Median raw")
	raw_globalmode = IJ.getValue(imp2, "Mode raw")
	raw_globalsd = IJ.getValue(imp2, "StdDev raw")
	
	IJ.run(imp2, "Subtract Background...", "rolling=20 disable")
	ip2 = imp2.getProcessor()
	cal2 = imp2.getCalibration()
	stats2 = IS.getStatistics(ip2, options, cal2)
	globalmean = stats2.mean
	globalmedian = stats2.median
	globalmode = stats2.mode
	globalsd = stats2.stdDev
	thr = globalmean + 3*globalsd
	
	IJ.setRawThreshold(imp2, thr, 65535)
	Prefs.blackBackground = True
	IJ.run(imp2, "Convert to Mask", "")
	
#	 Detection of condensates
	IJ.run("Set Measurements...", "area mean min centroid shape integrated redirect=None decimal=3")
	IJ.run(imp2, "Analyze Particles...", "size=0.04-500 exclude clear add")  # size unit is µm
	rt = ResultsTable.getResultsTable()
	curr_pnums = rt.size()
	#rt.show("Results")
	rm = RoiManager.getRoiManager()
	if curr_pnums != 0: # if particles were detected
		rt.reset()
		rm.runCommand(imp,"Show None")
		rm.runCommand(imp,"Show All")
		rm.runCommand(imp,"Measure")
		for j in range(0, rt.size()):
			rt.setValue("Date", j, edate)
			rt.setValue("Raw_gMean", j, raw_globalmean)
			rt.setValue("Raw_gMedian", j, raw_globalmedian)
			rt.setValue("Raw_gMode", j, raw_globalmode)
			rt.setValue("Raw_gSD", j, raw_globalsd)
			rt.setValue("gMean", j, globalmean)
			rt.setValue("gMedian", j, globalmedian)
			rt.setValue("gMode", j, globalmode)
			rt.setValue("gSD", j, globalsd)
			rt.setValue("Threshold", j, thr)
		rt.show("Results")
	else: # if no particels were detected
		rt.reset()
		rt.setValue("Area", 0, "NaN")
		rt.setValue("Mean", 0, "NaN")
		rt.setValue("Min", 0, "NaN")
		rt.setValue("Max", 0, "NaN")
		rt.setValue("X", 0, "NaN")
		rt.setValue("Y", 0, "NaN")
		rt.setValue("Circ.", 0, "NaN")
		rt.setValue("IntDen", 0, "NaN")
		rt.setValue("RawIntDen", 0, "NaN")
		rt.setValue("AR", 0, "NaN")
		rt.setValue("Round", 0, "NaN")
		rt.setValue("Solidity", 0, "NaN")
		rt.setValue("Date", 0, edate)
		rt.setValue("Raw_gMean", 0, raw_globalmean)
		rt.setValue("Raw_gMedian", 0, raw_globalmedian)
		rt.setValue("Raw_gMode", 0, raw_globalmode)
		rt.setValue("Raw_gSD", 0, raw_globalsd)
		rt.setValue("gMean",0, globalmean)
		rt.setValue("gMedian",0,globalmedian)
		rt.setValue("gMode",0,globalmode)
		rt.setValue("gSD",0,globalsd)
		rt.setValue("Threshold",0,threshold)
		rt.show("Results")
	
	# Extract each variable as a list of values from the table to calculate descriptive statistics
	area = rt.getColumnAsDoubles(rt.getColumnIndex("Area"))
	meanint = rt.getColumnAsDoubles(rt.getColumnIndex("Mean"))
	intden = rt.getColumnAsDoubles(rt.getColumnIndex("IntDen"))
	rounds = rt.getColumnAsDoubles(rt.getColumnIndex("Round"))
	ar = rt.getColumnAsDoubles(rt.getColumnIndex("AR"))
	circ = rt.getColumnAsDoubles(rt.getColumnIndex("Circ."))
	solidity = rt.getColumnAsDoubles(rt.getColumnIndex("Solidity"))
	# Collect into a dictionary
	params = {"area":area, "meanint":meanint, "intden":intden, "rounds":rounds, "ar":ar, "circ":circ, "solidity":solidity}

	# Generate DSS instance, input values of the variable, collect the instances into a dictionary
	dstats = {}
	for k,v in params.items():
		dss = DSS()
		for j in range(0, len(v)):
			dss.addValue(v[j])
		dstats[k] = dss
	
	# imp: original fluorescence image, ch2: phase contrast image, imp2: mask image, rt: ResultsTable
	return imp,ch2,imp2,rt,dstats,filename 
    # These return values are gathered into a tapple. 
    
#### Main code
# Insert a blank to prevent automatic modification on Excel.
edate = " "+edate1
# Make directories
dirD = os.path.join(str(dirD0), edate1 + "_output")
if not os.path.exists(dirD):
	os.mkdir(dirD)
dirBF = os.path.join(str(dirD), "BF")
if not os.path.exists(dirBF):
	os.mkdir(dirBF)                           
#Create a folder for mask images and ROI data
dirDR = os.path.join(str(dirD), "Drawings")
if not os.path.exists(dirDR):
	os.mkdir(dirDR)
dirGreen = os.path.join(str(dirD), "Green")
if not os.path.exists(dirGreen):
	os.mkdir(dirGreen)
dirCSV = os.path.join(str(dirD), edate1 + "_csv")
if not os.path.exists(dirCSV):
	os.mkdir(dirCSV)

# Acquire a list of files in the directory
filelist = os.listdir(str(dirS0))

# List comprehension, extract nd2 files.
nd2_files = [f for f in filelist if f.split(".")[-1] == "nd2"]
#filenames = [f.split(".")[0] for f in filelist]
nd2_files = sorted(nd2_files)

# Create a table that summarises the averages of particle parameters in a image file
particle_stat = ResultsTable()

for nd2_file in reversed(nd2_files):  # reversed() generates a revered iterator
    current_file_path = os.path.join(str(dirS0), nd2_file) 
    results = analyse_vitro_image(str(current_file_path))
    original = results[0] 
    ch2 = results[1]
    mask = results[2]   
    rt = results[3]    
    dstats = results[4]
    filename = results[5]
    
    save_result_table(str(dirCSV), filename, rt)
    save_image_as_tif(str(dirGreen), filename, original)
    save_image_as_tif(str(dirBF), filename, ch2)
    save_image_as_tif(str(dirDR), filename, mask)
    
    particle_stat.addValue("Date", edate)
    particle_stat.addValue("File_name", filename)
    particle_stat.addValue("particle_nums", dstats["area"].getN())
    particle_stat.addValue("mean_areas", dstats["area"].getMean())
    particle_stat.addValue("mean_meanints", dstats["meanint"].getMean())
    particle_stat.addValue("mean_intdens", dstats["intden"].getMean())
    particle_stat.addValue("sum_intdens", dstats["area"].getN()*dstats["intden"].getMean())
    particle_stat.addValue("mean_roundness", dstats["rounds"].getMean())
    particle_stat.addValue("mean_AR", dstats["ar"].getMean())
    particle_stat.addValue("mean_circ", dstats["circ"].getMean())
    particle_stat.addValue("mean_solidity", dstats["solidity"].getMean())
    particle_stat.addRow()

#　Remove the last empty row
particle_stat.deleteRow(particle_stat.size() - 1)
save_result_table(str(dirD), edate1+"_particle_stat", particle_stat)

print "Done. \n"
IJ.run("Clear Results")
rm = RoiManager.getRoiManager()
rm.reset()
IJ.run("Close All")
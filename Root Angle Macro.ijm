/*
 * ImageJ Macro to calculate root angle 
 * author: Jia Xuan Leong
 */


//identify horizontal line
/*
xleft = getWidth()/4;
xright = getWidth()/4*3;
ytop = getHeight()/5*4;
makeLine(xleftapprox, yapprox, xrightapprox, yapprox);
*/
roiManager("Show None");
img = getTitle();
setTool("line");
waitForUser("define horizontal base line, ie. top of coverslip, LEFT TO RIGHT");
getLine(x1, y1, x2, y2, linew)
linelength = abs(x2-x1);
slopeline = y1-y2;
if (slopeline<0) {
	linepositive = 0;
} else {
	linepositive = 1;
}
lineh = abs(slopeline);
angleBaseLine_radian = asin(lineh/linelength);
angleBaseLine_degree = angleBaseLine_radian * 180 / PI;

if (!linepositive) {
	angleBaseLine_degree = -angleBaseLine_degree;
}
if (linepositive) {
	makeRectangle(x1, 0, x2-x1, y1);
} else {
	makeRectangle(x1, 0, x2-1, y2);
}

run("Crop");
run("Rotate... ", "angle=" + angleBaseLine_degree + " grid=1 interpolation=Bilinear");

	
//segment roots and skeletonize
selectWindow(img);
run("Select None");
run("Duplicate...", "use");
img_process = getTitle();
run("8-bit");
run("Subtract Background...", "rolling=30 light");
run("Remove Outliers...", "radius=2 threshold=50 which=Dark");
run("Mean...", "radius=2");
run("Convert to Mask", "method=MaxEntropy background=Light");
run("Options...", "iterations=1 count=1 do=Dilate");
run("Options...", "iterations=3 count=1 do=Close");
run("Fill Holes");
run("Options...", "iterations=1 count=1 do=Skeletonize");

//get selection of root/skeletons
run("Clear Results");
roiManager("reset");
run("Create Selection");
roiManager("Add");
roiManager("Select", 0);
roiManager("Split");
roiManager("Select", 0);
roiManager("Delete");
roicount = roiManager("count");
run("Set Measurements...", "redirect=None decimal=5");
Table.create("trashroi");
for (roino = 0; roino < roicount; roino ++) {
	roiManager("select", roino);
	if (selectionType()==4)
		run("Area to Line");
	run("Measure");
	length = getResult("Length", nResults-1);
	lengthincm = length/10000; //scale in microns
	if (lengthincm < 2) {
		Table.set("roino", Table.size("trashroi"), roino, "trashroi");
	}
}
noOftrashroi = Table.size("trashroi");
trashroiarray = Table.getColumn("roino", "trashroi");
for (trashroi = 0; trashroi<noOftrashroi; trashroi++) {
	trashroiindex = Table.get("roino", trashroi);
	roiManager("select", trashroiindex);
	run("Clear");
}
roiManager("select", trashroiarray);
roiManager("delete");
close("trashroi");

//get coordinates that define the roots and angle
skelcount = roiManager("count");
rootcoords = "Root Coordinates";
Table.create(rootcoords);
for (roino = 0; roino < skelcount; roino ++) {
	roiManager("select", roino);
	getSelectionCoordinates(xpoints, ypoints);
	Array.getStatistics(ypoints, ytop, ybottom, mean, std);
	small_angle_y = ybottom - 100;
	for (index = 0; index < xpoints.length; index ++) {
		current_xpoint = xpoints[index];
		current_ypoint = ypoints[index];
		if (current_ypoint == ybottom) {
			xbottom = current_xpoint;
		}
		if (current_ypoint == ytop) {
			xtop = current_xpoint;
		}
	}

	makeLine(xbottom-100, small_angle_y, xbottom+100, small_angle_y);
	run("Plot Profile");
	plottitle = getTitle();
	Plot.getValues(xpoints, ypoints);
	for (point = 0; point < xpoints.length; point ++) {
		ypointvalue = ypoints[point];
		xpointvalue = xpoints[point];
		if (ypointvalue == 255) {
			close(plottitle);
			toUnscaled(xpointvalue);
			small_angle_x = xbottom-100+xpointvalue;
			point = xpoints.length;
		} 
	}
	if (ypointvalue == 0) {
		close(plottitle);
		setTool("point");
		waitForUser("small_angle_x not found, please make point");
		getSelectionCoordinates(xpoints, ypoints);
		small_angle_x = xpoints[0];
	}

	/*
	makePoint(xtop, ytop);
	roiManager("add");
	makePoint(xbottom, ybottom);
	roiManager("add");
	*/
	makeLine(xtop, ytop, xbottom, ybottom);
	waitForUser("check or modify general angle line");
	getLine(xtop, ytop, xbottom, ybottom, lineWidth);
	roiManager("add");
	run("Measure");
	/*
	linelength = getResult("Length", nResults-1);
	lineheight = ytop - ybottom;
	angle_to_horizontal_radians = asin(lineheight/linelength);
	angle_to_horizontal_degree = angle_to_horizontal_radians * 180 / PI;
	*/
	angle = getResult("Angle", nResults-1);
	rootcoordrow = Table.size(rootcoords);	
	Table.set("Root No.", rootcoordrow, roino+1, rootcoords);
	Table.set("X1", rootcoordrow, xtop, rootcoords);
	Table.set("Y1", rootcoordrow, ytop, rootcoords);
	Table.set("X2", rootcoordrow, xbottom, rootcoords);
	Table.set("Y2", rootcoordrow, ybottom, rootcoords);
	Table.set("General Angle", rootcoordrow, angle, rootcoords);
	makeLine(small_angle_x, small_angle_y, xbottom, ybottom);
	waitForUser("check or modify small angle line");
	getLine(small_angle_x, small_angle_y, xbottom, ybottom, lineWidth);
	roiManager("add");
	run("Measure");
	angle = getResult("Angle", nResults-1);
	Table.set("Small Angle", rootcoordrow, angle, rootcoords);
}
selectWindow(img_process);
run("RGB Color");
selectWindow(img);
roiManager("Show All without labels");
run("Flatten");
img_labelled = getTitle();
run("Combine...", "stack1=["+ img_labelled +"] stack2=["+ img_process +"]");
close(img);
close("Results");
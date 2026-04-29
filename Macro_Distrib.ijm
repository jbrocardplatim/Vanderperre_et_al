//Macro Image J de mesure de distribution de signal Ubx à l'intérieur de noyaux
//définis par LaminB, dans des régions concentriques en partant de la périphérie
//développée par Jacques Brocard, PLATIM 2023 pour Samir Mérabet (IGFL)

//Pré-requis : stack ouvert (.tif ou .czi) de x canaux, dont un vert et un rouge = laminB
//et autant de z que désiré + ROI Manager contenant des ROIs carrées de ~25 um de côté

var title="";
var dir="";
run("Set Measurements...", "area mean area_fraction limit redirect=None decimal=3");

pixels_per_micron=verif_stack();
//A ce stade, un stack red et un stack green sont ouverts

nROIs=roiManager("Count");
print(title+" "+nROIs+" ROIs");
overalW=floor(4*pixels_per_micron/2); //nb itérations nécessaires pour couvrir 4 microns
meanO=newArray(nSlices);

//Pour chaque ROI ->
for (r=1;r<=nROIs;r++){
	print("");
	
	//Image "red" = lamin
	selectWindow("red");
	roiManager("Select", (r-1));
	run("Duplicate...", "title=RED_ duplicate");
	run("Gaussian Blur 3D...", "x=1 y=1 z=1");
	run("Z Project...", "projection=[Max Intensity]");
	selectWindow("MAX_RED_");
	run("Enhance Contrast", "saturated=0.000001");
	getMinAndMax(min, max);
	if (max<100) max=100;
	close();
	roiManager("Reset");
	selectWindow("RED_");
	resetMinAndMax();
	run("Select All");
	roiManager("Add");
	//Ré-échelonner les niveaux de gris en fonction de min & max avant de seuiller
	setMinAndMax(min,max);
	run("Apply LUT", "stack");
	run("Duplicate...", "title=outer duplicate");
	//Seuiller a minima pour garder le plus de signal possible
	setThreshold(25, 255);
	setOption("BlackBackground", true);
	run("Convert to Mask", "method=Default background=Dark black");
	//Exclure les bords pour garder uniquement le signal central
	run("Analyze Particles...", "size=10-Infinity show=Masks exclude in_situ stack");
	run("Close-", "stack");
	run("Fill Holes", "stack");
	
	//Chercher la slice qui contient le plus de signal = sMAX
	for (s=0;s<nSlices;s++){
		setSlice(s+1);
		run("Select All");
		getStatistics(areaO,meanO[s]);
	}
	sMAX=0;
	for (s=0;s<nSlices;s++){
		if (meanO[s]>meanO[sMAX]) sMAX=s;
	}
	
	//RINGS en commençant au contour extérieur
	setSlice(sMAX+1);
	run("Select All");
	run("Copy");
	close("outer");
	run("Internal Clipboard");
	run("Analyze Particles...", "size=10-Infinity show=Nothing exclude clear add");
	//print(overalW);
	for (i=1; i<=overalW; i++){
		run("Options...", "iterations=2 count=1 black do=Erode");
		run("Analyze Particles...", "size=2-Infinity show=Nothing exclude add");
	}
	close();

	selectWindow("ROI Manager");
	roiManager("Save",dir+title+"_rings_nuc"+r+".zip");
	roiManager("Reset");

	//Image "green" = Ubx
	selectWindow("green");
	roiManager("Open",dir+title+".zip");
	roiManager("Select", (r-1));
	run("Duplicate...", "title=GREEN_ duplicate");
	run("Gaussian Blur 3D...", "x=1 y=1 z=1");
	run("Z Project...", "projection=[Max Intensity]");
	getMinAndMax(min, max);
	close();
	roiManager("Reset");
	selectWindow("GREEN_");
	resetMinAndMax();
	//Ré-échelonner les niveaux de gris en fonction de min & max avant de seuiller
	setMinAndMax(min,max);
	run("8-bit");

	roiManager("Open", dir+title+"_rings_nuc"+r+".zip");
	mask_images("GREEN_",5); //Segmentation des 5% de pixels les plus intenses en green

	//Calcul, impression et sauvegarde de l'overlap entre green et red, en jaune
	print("RINGS_nuc"+r+" (µm) \tAREA (µm²) \tAREA POS (µm²)  \tAREA POS (%)");
	selectWindow("Mask of GREEN_");

	area=newArray(overalW+1);
	mean=newArray(overalW+1);
	for (i=1; i<=overalW; i++){
		roiManager("Select",(i-1));
		getStatistics(area[i],mean[i]);
	}
	roiManager("Deselect");
	
	areaR=newArray(overalW+1);
	areaRpos=newArray(overalW+1);
	areaRpos[0]=0;
	for (i=1; i<overalW; i++){
		areaR[i]=area[i]-area[i+1];
		areaRpos[i]=(mean[i]*area[i]-mean[i+1]*area[i+1])/255;
		if (areaRpos[i]<0.01) areaRpos[i]=0;
		areaRpos[0]=areaRpos[0]+areaRpos[i];
	}
	
	for (i=1; i<overalW; i++){
		print(2*i/pixels_per_micron+"\t"+areaR[i]+"\t"+areaRpos[i]+"\t"+floor(areaRpos[i]/areaRpos[0]*1000)/10);
	}

	saveAs("Tiff",dir+title+"_rings_nuc"+r+".tif");
	close();
	close("RED_");
	close("GREEN_");
	roiManager("Reset");
	roiManager("Open",dir+title+".zip");	

}

selectWindow("Log");
saveAs("Txt",dir+title+"_results.txt");
close("red"); 
close("green");
selectWindow("ROI Manager");
run("Close");


function verif_stack(){
	//Macro de détectkion du format du stack et du ROI Manager
	//Séparation des canaux green et red pour la suite des opérations
	title=getTitle();
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);

	while (!(substring(unit,0,6)=="micron" || unit=="µm")){
		waitForUser("PROBLEME unités de l'image : \n Cliquez 'Cancel' pour annuler \n OU modifiez les unités en microns et cliquez 'OK'"); 
	}
	pix=floor(1/pixelHeight);

	if (channels==1) {
		print("ABORT MacroSolene6Samir, au moins DEUX canaux nécessaires !");
		exit;
	}
	while (!(isOpen("ROI Manager"))){
		waitForUser("PAS de ROI Manager ouvert : \n Cliquez 'Cancel' pour annuler \n OU enregistrez des ROIs et cliquez 'OK'"); 
	}
	ch_red=0; ch_green=0;
	while (!(ch_red<=channels && ch_green<=channels && ch_red != ch_green)){
		//Dialog box for parameter initialization
		Dialog.create("Initialization");
		Dialog.addString("Nb canaux = ", channels);
		Dialog.addNumber("canal rouge = ",channels);
		Dialog.addNumber("canal vert = ",channels-1);
		Dialog.show();
		
		bla=Dialog.getString();
		ch_red=Dialog.getNumber();
		ch_green=Dialog.getNumber();
	}
	
	selectWindow(title);
	run("Select All");
	run("Duplicate...", "title=red duplicate channels="+ch_red);
	selectWindow(title);
	run("Select All");
	run("Duplicate...", "title=green duplicate channels="+ch_green);
	
	selectWindow(title);
	dir=getDirectory("image");
	title=substring(title,0,lengthOf(title)-4);
	saveAs("Tiff",dir+title+".tif");
	close();
	
	selectWindow("ROI Manager");
	roiManager("Save",dir+title+".zip");

	return pix;
	
}


function mask_images(im,seuilA){
	//Macro de seuillage d'un pourcentage donné des pixels (seuilA) sur l'image "im"
	selectWindow(im);
	setSlice(sMAX+1); 

	area=seuilA+1; pix=0;
	while (area>seuilA){
		pix++;
		setThreshold(pix,255);
		roiManager("Select",0);
		run("Analyze Particles...", "summarize");
		area=Table.get("%Area",pix-1);
	}
	setThreshold(pix, 255);
	roiManager("Select",0);
	run("Analyze Particles...", "size=1-Infinity pixel show=Masks slice");
	run("Grays");
	close("Summary of "+im);
}

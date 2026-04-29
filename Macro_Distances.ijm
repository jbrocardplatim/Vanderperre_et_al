//Macro Image J de mesure de distance signal FISH vs enveloppe nucléaire
//développée par Jacques Brocard, PLATIM 2023 pour Samir Mérabet (IGFL)
//Nécessite l'installation du plugin DiAna : https://imagej.net/plugins/distance-analysis

//Pré-requis : stack ouvert (.tif ou .czi) de x canaux, dont un vert et un rouge = noyau
//et autant de z que désiré + ROI Manager contenant des ROIs carrées de ~25 um de côté
var title="";
var dir="";
var nROIs;
seuil_FISH=0.005; //pourcentage de pixels satures sur images FISh avant detection
verif_stack();

//A ce stade, un stack red et un stack green vérifiés
volA=newArray(nROIs);
volB=newArray(nROIs);
centerTocenter=newArray(nROIs);
centerToedge=newArray(nROIs);
//Pour chaque ROI ->
print("EXECUTION MacroMD_8bit_v4 EN COURS...");
for (i=0;i<nROIs;i++){
	
	//Image "red" = lamin
	roiManager("Open",dir+title+".zip");
	selectWindow("red");
	roiManager("Select", i);
	run("Duplicate...", "title=3 duplicate");
	run("Gaussian Blur 3D...", "x=1 y=1 z=1");
	run("Z Project...", "projection=[Max Intensity]");
	resetMinAndMax();
	run("Enhance Contrast", "saturated=0.01");
	getMinAndMax(min, max);
	if (max<100) max=100;
	close();
	//print(min, max);
	selectWindow("3");
	//Ré-échelonner les niveaux de gris en fonction de min & max avant de seuiller
	setMinAndMax(min,max);
	run("Apply LUT", "stack");
	//Seuiller a minima pour garder le plus de signal possible
	setThreshold(25, 255);
	setOption("BlackBackground", true);
	run("Convert to Mask", "method=Default background=Dark black");
	run("Analyze Particles...", "size=10-Infinity show=Masks stack exclude");
	run("Grays");
	rename("temp");
	close("3");
	for (s=1;s<=nSlices;s++){
		selectWindow("temp");
		setSlice(s);
		roiManager("reset");
		run("Select None");
		//Exclure les bords pour garder uniquement le signal central
		run("Analyze Particles...", "size=5-Infinity add clear");
		r=roiManager("Count");
		if (r>=1) {
			roiManager("Combine");
			roiManager("Delete");
			roiManager("Add");
			setForegroundColor(255,255,255);
			roiManager("Select",0);
			run("Convex Hull");
			run("Fill", "slice");
		}else{
			setForegroundColor(0,0,0);
			run("Select All");
			run("Fill", "slice");
		}
	}
	rename("3");
	
	//Image "green" = signal FISH
	roiManager("Open",dir+title+".zip");
	selectWindow("green");
	roiManager("Select", i);
	run("Duplicate...", "title=2 duplicate stack");
	run("Gaussian Blur 3D...", "x=1 y=1 z=1");
	run("Z Project...", "projection=[Max Intensity]");
	//Ré-échelonner les niveaux de gris en fonction de min & 0.2% de points saturés avant de seuiller
	run("Enhance Contrast", "saturated="+seuil_FISH);
	getMinAndMax(min, max);
	//print(min, max);
	close();
	selectWindow("2");
	setMinAndMax(min, max);
	//run("8-bit");
	run("Apply LUT", "stack");
	//Seuiller uniquement les points saturés = signal FISH
	setThreshold(250, 255);
	setOption("BlackBackground", true);
	run("Convert to Mask", "method=Default background=Dark black");
	run("Analyze Particles...", "size=0.2-Infinity show=Masks exclude in_situ stack");
	//Ne conserver que les signaux FISH détectés à l'INTERIEUR de l'enveloppe nucléaire
	run("Divide...", "value=255 stack");
	imageCalculator("Multiply stack", "2","3");
	run("Close-", "stack");

	selectWindow("2");
	run("Z Project...", "projection=[Max Intensity]");
	run("Select All");
	getStatistics(area,mean);
	close();

	//Dans le cas où l'image "2" contient bien un signal FISH...
	if (mean>0){
		run("Merge Channels...", "c1=3 c2=2 create keep");
		if (i<10){
			cell="cell0";
		}else{
			cell="cell";
		}
		saveAs("Tiff", dir+title+"_"+cell+i+".tif");
		close();
		//... faire tourner le plugin DiAna (JF Gilles, Methods, 2017)
		run("DiAna_Analyse", "img1=2 img2=3 lab1=2 lab2=3 adja kclosest=1 dista=50.0 measure");
		selectWindow("ObjectsMeasuresResults-A");
		IJ.renameResults("Results");
		volA[i]=getResult("Volume (unit)");
		selectWindow("Results");
		run("Close");
		selectWindow("ObjectsMeasuresResults-B");
		IJ.renameResults("Results");
		volB[i]=getResult("Volume (unit)");
		selectWindow("Results");
		run("Close");
		selectWindow("AdjacencyResults");
		IJ.renameResults("Results");
		centerTocenter[i]=getResult("Dist CenterA-CenterB");
		centerToedge[i]=getResult("Dist min CenterA-EdgeB");
		selectWindow("Results");
		run("Close");
		print(cell+i+", "+volA[i]+", "+volB[i]+", "+centerTocenter[i]+", "+centerToedge[i]);
	}
	close("2"); close("3");
}

selectWindow("ROI Manager");
roiManager("Save",dir+title+".zip");
run("Close");

//Ecrire les mesures dans un fichier texte nommé identiquement à l'image de départ
fili=File.open(dir+title+".txt");
print(fili,"Cell # \t volFISH \t vol noyau \t R théo (um) \t R réel (um) \t dist (um)");
for (i=0;i<nROIs;i++){
	if (i<10){
		cell="cell0";
	}else{
		cell="cell";
	}
	Rtheo=Math.pow((3*volB[i])/(4*PI),1/3); 
	Rreel=centerTocenter[i]+centerToedge[i];
	print(fili,cell+i+"\t"+volA[i]+"\t"+volB[i]+"\t"+Rtheo+"\t"+Rreel+"\t"+centerToedge[i]);
}
close("red"); close("green");
print("EXECUTION MacroMD_8bit_v4 TERMINEE.");


function verif_stack(){

	title=getTitle();
	dir=getDirectory("image");
	title=substring(title,0,lengthOf(title)-4);
	saveAs("Tiff",dir+title+".tif");
	rename(title);
	
	getDimensions(width, height, channels, slices, frames);
	if (channels==1) {
		print("ABORT MacroMD_8bit, au moins DEUX canaux nécessaires !");
		exit;
	}
	while (!(isOpen("ROI Manager"))){
		waitForUser("PAS de ROI Manager ouvert : \n Cliquez 'Cancel' pour annuler \n OU enregistrez des ROIs et cliquez 'OK'"); 
	}
	
	selectWindow("ROI Manager");
	nROIs=roiManager("Count");
	roiManager("Save",dir+title+".zip");
	run("Close");
	
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
	
	close(title);
	
}

//Macro Image J de mesure de colocalisation entre Ubx et FISH dans des noyaux,
//rédigée par Jacques Brocard, PLATIM 2025 pour S.Vonau & S. Mérabet (IGFL)

//Pré-requis : stack ouvert (.tif ou .czi) de 2 canaux, un blanc = Ubx et un rouge = FISH
//et autant de z que désiré + ROI Manager contenant des ROIs carrées de ~25 um de côté au plan
//équatorial de noyaux d'intérêt

//--- INITIALIZATION
dir = getDirectory("Image");
tit=getTitle();
tit=substring(tit,0,lengthOf(tit)-4);
rename(tit);
percent=0.15; //Pourcentage des pixels Ubx les plus intenses pris en compte pour la segmentation
min_FISH_size=0.1; //Taille minimum de signal FISH segmenté = 0.1 µm²
nROIs=roiManager("Count");
run("Set Measurements...", "area mean area_fraction redirect=None decimal=6");
print("#Nuc \tArea (µm²) \t%Ubx \t%FISH \t%overlap \t%random");

selectWindow(tit);
//Pour chaque ROI ->
for (r=0;r<nROIs;r++){
	//Duplicate le noyau considéré et séparer les couleurs
	roiManager("Select",r);
	run("Duplicate...", "title=nuc duplicate");
	run("Split Channels");
	 //A partir du signal Ubx, réaliser une projection de 5 coupes soit 0.8 µm...
	selectWindow("C1-nuc");
	sli=getSliceNumber();
	//print(sli);
	run("Z Project...", "start="+sli-2+" stop="+sli+2+" projection=[Max Intensity]");
	//... et segmenter le contour *convexe* du noyau
	segment_nuc("C1-nuc");
	roiManager("Select",nROIs);
	run("Convex Hull");
	roiManager("Add");
	roiManager("Select",nROIs);
	roiManager("Delete");
	roiManager("Select",nROIs);
	//Instruction à rajouter pour permettre à l'utilisateur de tracer un contour manuellement
	//waitForUser("1. Delete bad contour \n2. Draw new one \n3. Add to ROI Manager \n4. Select ROI \n5. Click OK");
	
	//Répéter la projection du signal Ubx à partir de 5 coupes soit 0.8 µm...
	selectWindow("C1-nuc");
	run("Select All");
	run("Z Project...", "start="+sli-2+" stop="+sli+2+" projection=[Max Intensity]");
	rename("C1-proj");
	roiManager("Select",nROIs);
	//... et sélectionner les *percent*% des pixels les plus intenses
	run("Enhance Contrast", "saturated="+percent);
	getMinAndMax(min, max); per=0;
	while (per<percent){
		max=floor(0.99*max);
		setThreshold(max, 65535, "raw");
		roiManager("Select",nROIs);
		run("Measure");
		per=getResult("%Area", 0)/100;
		close("Results");
	}
	//Produire un masque pour Ubx segmenté
	setThreshold(max+1, 99999);
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Options...", "iterations=1 count=1 black do=Open");
	close("C1-nuc");
	
	selectWindow("C2-nuc");
	//A partir du signal FISH, réaliser une projection de 5 coupes soit 0.8 µm...
	run("Z Project...", "start="+sli-2+" stop="+sli+2+" projection=[Max Intensity]");
	rename("temp");
	run("Select All");
	getStatistics(area, mean);
	//... puis utiliser un seuil de 100x signe moyen pour produire un masque de FISH segmenté
	setThreshold(mean*100, 99999);
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Analyze Particles...", "size="+min_FISH_size+"-Infinity show=Masks exclude");
	run("Grays");
	run("Options...", "iterations=1 count=1 black do=Erode");
	rename("C2-proj");
	close("C2-nuc"); close("temp");

	//Calculer le nb de pixels de chaque masque de segmentation -
	//- Ubx
	selectWindow("C1-proj");
	roiManager("Select", nROIs);
	getStatistics(area,mean1);
	mean1=floor(100000*mean1/255)/1000;	
	//- FISH
	selectWindow("C2-proj");
	roiManager("Select", nROIs);
	getStatistics(area,mean2);
	mean2=floor(100000*mean2/255)/1000;
	//- coloc après avoir créé le masque d'overlap correspondant
	imageCalculator("AND create", "C1-proj","C2-proj");
	roiManager("Select", nROIs);
	getStatistics(area,mean3);
	mean3=100*mean3/255;
	//Enfin, calculer le nb de pixels d'overlap aléatoire...
	mean4=(mean1*mean2)/100;
	close();
	//... et imprimer les résultats
	print("Nuc-"+(r+1)+"\t"+area+"\t"+mean1+"\t"+mean2+"\t"+mean3+"\t"+mean4);
	
	//Produire une image "résultat" à partir des masques et du contour du noyau
	run("Merge Channels...", "c1=C2-proj c2=C1-proj ignore");
	roiManager("Select", nROIs);
	run("Add Selection...");
	saveAs("Tiff", dir+tit+"_nuc"+(r+1)+".tif");
	
	roiManager("Select", nROIs);
	roiManager("Delete");
	close();
}
selectWindow("Log");
saveAs("Text",dir+tit+".txt");
close("Log");
close("ROI Manager");
	
	
function segment_nuc(t){
	min_nuc_size=100; //Taille minimum des noyaux segementés = 100 µm²
	selectWindow(t);
	run("Select All");
	run("Copy");
	run("Internal Clipboard");
	if (bitDepth()==16){
		run("32-bit");
		run("Square Root");
	}
	//Soustraire le bruit de fond de l'image Ubx...
	run("Subtract Background...", "rolling=3 create");
	run("Select All");
	getStatistics(area, mean);
	//... et utiliser le seuil automatique "Default" pour produire un masque
	setAutoThreshold("Default dark");
	setThreshold(mean+1, 65535, "raw");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	//Remplir les trous et se débarrasser des petites surfaces avec l'instruction "Open"...
	run("Fill Holes");
	run("Options...", "iterations="+floor(min_nuc_size/5)+" count=1 black do=Open");
	run("Fill Holes");
	run("Options...", "iterations=1 count=1 black do=Erode");
	//... puis ajouter le contour du noyau au ROI Manager
	run("Analyze Particles...", "size="+min_nuc_size+"-Infinity exclude add");
	close(); close("MAX_C1-nuc");
}

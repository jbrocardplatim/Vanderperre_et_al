//Macro Image J de production de cartes de densité à partir d'un ensemble de noyaux analysés
//avec la macro "Macro_Coloc.ijm"
//rédigée par Jacques Brocard, PLATIM 2025 pour S.Vonau & S. Mérabet (IGFL)

//Pré-requis : images ouvertes de tous les noyaux à compiler, avec chacun 2 masques, 
//un vert = Ubx et un rouge = FISH + contour de noyau dans l'overlay

//--- INITIALISATION
setForegroundColor(255, 255, 255);
ni=nImages();
targetSize=0.05; //taille des pixels sur l'image résultante
//Etablir la liste de tous les noyaux à compiler
list=newArray(ni+1);
for (i=1;i<=ni;i++){
	selectImage(i);
	list[i]=getTitle();
}
//S'il n'y a pas d'images ouvertes, passer directement à l'étape suivante; sinon :
if (list.length>1){
	//Produire un stack vide pour compiler les images ouvertes
	newImage("C1-density-map", "8-bit black", 600, 600, ni);
	newImage("C2-density-map", "8-bit black", 600, 600, ni);
	
	//Pour chaque noyau...
	for (i=1;i<=ni;i++){
		selectWindow(list[i]);
		t=getTitle();
		//Adapter la taille des pixels de l'image à la taille visée = targetSize
		adapt_image(t);
		//Récupérer le contour du noyau dans le ROI Manager et séparer les canaux
		run("To ROI Manager");
		run("Split Channels");
		close(t+" (blue)");
		
		//Copier le contenu du canal vert *au milieu* du stack1 de compilation
		selectWindow(t+" (green)");
		roiManager("Select",0);
		run("Copy");
		close();
		selectWindow("C1-density-map");
		setSlice(i);
		makeOval(300, 300, 600, 600);
		run("Paste");
		
		//Copier le contenu du canal rouge *au milieu* du stack2 de compilation
		selectWindow(t+" (red)");
		roiManager("Select",0);
		run("Copy");
		close();
		selectWindow("C2-density-map");
		setSlice(i);
		makeOval(300, 300, 600, 600);
		run("Paste");
	}
	//Inscrire la taille des pixels des stacks de compilation 
	selectWindow("C1-density-map");
	run("Select All");
	run("Properties...", "unit=micron pixel_width="+targetSize+" pixel_height="+targetSize+" voxel_depth=1");
	selectWindow("C2-density-map");
	run("Select All");
	run("Properties...", "unit=micron pixel_width="+targetSize+" pixel_height="+targetSize+" voxel_depth=1");
	roiManager("Reset");
	waitForUser("Save density maps in the same directory and click OK");
	dir=getDirectory("image");
	run("Close All");
}else{
	dir=getDirectory("");
}
//Ouvre la carte de densité C1 (=Ubx) et réalise une projection moyenne...
print(dir);
open(dir+"C1-density-map.tif");
run("Z Project...", "projection=[Average Intensity]");
run("Green");
setMinAndMax(0,125);
rename("AVG");
getPixelSize(unit, pixelWidth, pixelHeight);

//... puis en établit le contour moyen
run("Duplicate...", "title=mask");
setAutoThreshold("Default dark");
setThreshold(12, 255); //Seuil correspond à 0.05 * 255 = on contoure 95% du signal moyen
setOption("BlackBackground", true);
run("Convert to Mask");
//Uniformisation du contour et production du masque de l'enveloppe convexe
run("Options...", "iterations=20 count=1 black do=Close");
run("Analyze Particles...", "size=1-Infinity exclude add");
roiManager("Select", 0);
run("Convex Hull");
roiManager("Add");
roiManager("Select", 0);
roiManager("Delete");
roiManager("Select", 0);
getStatistics(area, mean);
run("Fill", "slice");

//A partir des dimensions du masque du noyau...
radius=Math.sqrt(area/PI)/pixelWidth;
area=10; iter=0;
//... établir une succession d'anneaux concentriques à 0.5 µm d'écart [10 itérations à 0.05 µm] 
//tant que l'aire restante > 5 µm²...
while(area>5){
	run("Options...", "iterations=10 count=1 black do=Erode");
	run("Analyze Particles...", "size=1-Infinity exclude add");
	iter=iter+1;
	roiManager("Select",iter);
	getStatistics(area);
}
close();
//... imprimer les mesures de signal à l'intérieur de chacun et sauvegarder l'image "AVG" résultante
print("C1-density-map");
print("Ring dist(µm) \t Area (µm²) \tMean Ubx");
print_ring_signal("AVG",iter);
run("From ROI Manager");
saveAs("Tiff", dir+"AVG.tif");
close(); close();

//Ouvre la carte de densité C2 (=FISH) et réalise une projection moyenne...
open(dir+"C2-density-map.tif");
run("Z Project...", "projection=[Average Intensity]");
run("Red");
setMinAndMax(0,25);
rename("AVG FISH");
print("\nC2-density-map");
print("Ring dist(µm) \t Area (µm²) \tMean FISH");
print_ring_signal("AVG FISH",iter);
run("From ROI Manager");
saveAs("Tiff", dir+"AVG_FISH.tif");
close(); close();

//Save final text file
selectWindow("Log");
saveAs("Text",dir+"C1-C2-density-maps.txt");
close("Log");
close("ROI Manager");


function adapt_image(t){
	//A partir du stack t, récupérer la taille des pixels et calculer le facteur de scaling
	getPixelSize(unit, pixelWidth, pixelHeight);
	factor=pixelWidth/targetSize;
	
	//A partir du contour du noyau de l'Overlay, produire une image binaire du noyau
	run("To ROI Manager");
	run("Select All");
	newImage("Mask", "8-bit black", 600, 600, 1);
	selectWindow("ROI Manager");
	roiManager("Select", 0);
	run("Fill", "slice");
	
	//Ajuster le masque du noyau à l'échelle désirée
	run("Select All");
	run("Scale...", "x="+factor+"+ y="+factor+" width="+floor(600*factor)+" height="+floor(600*factor)+" create");
	rename("newMask");
	close("Mask");
	
	//Ajuster le stack image à l'échelle désirée
	selectImage(t);
	H=getHeight();
	H=floor(H*factor);
	W=getWidth();
	W=floor(W*factor);
	run("Select All");
	run("Scale...", "x="+factor+"+ y="+factor+" width="+W+" height="+H+" create");
	rename("temp");
	close(t);
	
	//Ajouter le contour de noyau en Overlay de l'image
	selectImage("newMask");
	run("Select All");
	setAutoThreshold("Default dark");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Analyze Particles...", "size=1-Infinity exclude add");
	close();
	
	selectImage("temp");
	rename(t);
	roiManager("Select", 1);
	run("Add Selection...");
	roiManager("Reset");
}

function print_ring_signal (t, iter){
	//Mesurer le signal à l'intérieur de chaque cercle puis établir et imprimer le signal propre à chaque anneau
	selectWindow(t);
	area=newArray(iter+1);
	mean=newArray(iter+1);
	for (i=0;i<iter+1;i++){
		roiManager("Select",i);
		getStatistics(area[i],mean[i]);
	}
	for (i=0;i<iter;i++){
			mean[i]=(mean[i]*area[i]-mean[i+1]*area[i+1]);
			area[i]=area[i]-area[i+1];
			mean[i]=mean[i]/area[i];
	}
	for (i=0;i<iter+1;i++){
		print(i*targetSize*10+"\t"+area[i]+"\t"+mean[i]);
	}
}

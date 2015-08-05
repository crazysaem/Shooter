#!BPY

"""
Name: 'Shooter World Exporter (*.wld)'
Blender: 249
Group: 'Export'
Tooltip: 'Wikibooks sample exporter'
"""
import bpy
import Blender
from Blender import *
import BPyMessages
import struct

def write(filename):
	out = file(filename, "wb")
	out.write("WLDF")
	sce = bpy.data.scenes.active
	z = 0
	for ob in sce.objects:
		if ob.type == "Mesh" :
			z=z+1
	data = struct.pack('i', z)
	out.write(data)
	for ob in sce.objects:
		#if ob.type == "Mesh" : out.write(ob.type + ": " + ob.name + "\n")
		a = 0
		if ob.type == "Mesh" :
			# Begin: TexturePfad herausfinden
			a = a + 1
			mesh = ob.getData(mesh=1)
			matl = mesh.materials
			mat = matl[0]
			texl = mat.getTextures()
			mtex = texl[0]
			tex = mtex.tex
			img = tex.getImage()
			imgname = img.getFilename()
			# Ende: TexturePfad = imgname
			# Begin: Texturname aus TexturPfad filtern
			x = imgname.count("\\")
			for lauf in range(x):
				y = imgname.find("\\") + 1
				imgname = imgname[y:]
			# Ende: Texturname = imgname
			# Begin: TexturnameLaenge auf 32 setzen; RestLaenge wird durch "!" ersetzt
			out.write("TexT")
			fillname = 32 - len(imgname)
			for lauf in range(fillname):
				imgname=imgname+"!"
			out.write(imgname)
			# Ende
			data = struct.pack('i', tex.repeat[0]) #Xrepeat
			out.write(data)
			data = struct.pack('i', tex.repeat[1]) #Yrepeat
			out.write(data)
			'''
			out.write("LRS:")
			data = struct.pack('f', ob.LocX)
			out.write(data)
			data = struct.pack('f', ob.LocY)
			out.write(data)
			data = struct.pack('f', ob.LocZ)
			out.write(data)
			data = struct.pack('f', ob.RotX)
			out.write(data)
			data = struct.pack('f', ob.RotY)
			out.write(data)
			data = struct.pack('f', ob.RotZ)
			out.write(data)
			data = struct.pack('f', ob.SizeX)
			out.write(data)
			data = struct.pack('f', ob.SizeY)
			out.write(data)
			data = struct.pack('f', ob.SizeZ)
			out.write(data)
			'''
			out.write("Vert")
			data = struct.pack('i', len(mesh.verts))
			out.write(data)
			me_tmp = Mesh.New()
			me_tmp.getFromObject(ob.name)
			me_tmp.transform(ob.matrixWorld)
			#for vert in mesh.verts:
			for vert in me_tmp.verts:
				#out.write( 'v %f %f %f\n' % (vert.co.x, vert.co.y, vert.co.z) )
				data = struct.pack('f', vert.co.x)
				#out.write("X")
				out.write(data)
				data = struct.pack('f', vert.co.y)
				#out.write("Y")
				out.write(data)
				data = struct.pack('f', vert.co.z)
				#out.write("Z")
				out.write(data)
			out.write("Norm")
			data = struct.pack('i', len(mesh.verts))
			out.write(data)
			#for vert in mesh.verts:
			for vert in me_tmp.verts:
				#out.write( 'v %f %f %f\n' % (vert.no.x, vert.no.y, vert.no.z) )
				data = struct.pack('f', vert.no.x)
				#out.write("X")
				out.write(data)
				data = struct.pack('f', vert.no.y)
				#out.write("Y")
				out.write(data)
				data = struct.pack('f', vert.no.z)
				#out.write("Z")
				out.write(data)
			out.write("FVIN")
			data = struct.pack('i', len(mesh.faces))
			out.write(data)
			for face in mesh.faces:
				#out.write("  Quad %s %s %s %s\n" % (Face.v[0].index, Face.v[1].index,   Face.v[2].index, Face.v[3].index)) 
				if len(face.v) == 3: # Triangle
					#File.write("  Triangle %s %s %s\n" % (Face.v[0].index, Face.v[1].index, Face.v[2].index))
					data = struct.pack('i', face.v[0].index)
					out.write(data)
					data = struct.pack('i', face.v[1].index)
					out.write(data)
					data = struct.pack('i', face.v[2].index)
					out.write(data)
					data = struct.pack('i', face.v[0].index)
					out.write(data)
				elif len(face.v) == 4: # Quad
					#File.write("  Quad %s %s %s %s\n" % (Face.v[0].index, Face.v[1].index,   Face.v[2].index, Face.v[3].index))
					data = struct.pack('i', face.v[0].index)
					out.write(data)
					data = struct.pack('i', face.v[1].index)
					out.write(data)
					data = struct.pack('i', face.v[2].index)
					out.write(data)
					data = struct.pack('i', face.v[3].index)
					out.write(data)
			out.write("UVCO")
			data = struct.pack('i', len(mesh.faces))
			out.write(data)
			for face in mesh.faces:
				#out.write("%f %f %f %f" % (face.uv[0][0], face.uv[0][1],   face.uv[1][0], face.uv[1][1])) 
				if len(face.v) == 3: # Triangle
					data = struct.pack('f', face.uv[0][0])
					out.write(data)
					data = struct.pack('f', face.uv[0][1])
					out.write(data)
					
					data = struct.pack('f', face.uv[1][0])
					out.write(data)
					data = struct.pack('f', face.uv[1][1])
					out.write(data)
					#out.write("%f %f %f %f" % (face.uv[2][0], face.uv[2][1],   face.uv[3][0], face.uv[3][1])) 
					
					data = struct.pack('f', face.uv[2][0])
					out.write(data)
					data = struct.pack('f', face.uv[2][1])
					out.write(data)
					
					data = struct.pack('f', face.uv[0][0])
					out.write(data)
					data = struct.pack('f', face.uv[0][1])
					out.write(data)	
				elif len(face.v) == 4: # Quad
					data = struct.pack('f', face.uv[0][0])
					out.write(data)
					data = struct.pack('f', face.uv[0][1])
					out.write(data)
					
					data = struct.pack('f', face.uv[1][0])
					out.write(data)
					data = struct.pack('f', face.uv[1][1])
					out.write(data)
					#out.write("%f %f %f %f" % (face.uv[2][0], face.uv[2][1],   face.uv[3][0], face.uv[3][1])) 
					
					data = struct.pack('f', face.uv[2][0])
					out.write(data)
					data = struct.pack('f', face.uv[2][1])
					out.write(data)
					
					data = struct.pack('f', face.uv[3][0])
					out.write(data)
					data = struct.pack('f', face.uv[3][1])
					out.write(data)	
			del mesh
Blender.Window.FileSelector(write, "Export")
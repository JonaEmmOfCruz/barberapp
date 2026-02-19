// Configurar multer para PDFs
const storagePDF = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = 'uploads/pdfs';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, 'pdf-' + uniqueSuffix + ext);
  }
});

const uploadPDF = multer({ 
  storage: storagePDF,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    if (file.mimetype === 'application/pdf') {
      cb(null, true);
    } else {
      cb(new Error('Solo se permiten archivos PDF'));
    }
  }
});

// Ruta para subir PDF de barbero
router.post('/barbero-pdf', uploadPDF.single('pdf'), async (req, res) => {
  try {
    const { barberoId } = req.body;

    if (!barberoId) return res.status(400).json({ message: 'barberoId es requerido' });
    if (!req.file) return res.status(400).json({ message: 'No se recibió ningún PDF' });

    const pdfUrl = `/uploads/pdfs/${req.file.filename}`;

    const barbero = await Barbero.findByIdAndUpdate(
      barberoId,
      { 'experiencia.pdf': pdfUrl },
      { new: true }
    );

    if (!barbero) return res.status(404).json({ message: 'Barbero no encontrado' });

    res.json({
      success: true,
      message: 'PDF subido exitosamente',
      pdfUrl
    });

  } catch (error) {
    console.error('Error al subir PDF:', error);
    res.status(500).json({ message: 'Error al subir PDF', error: error.message });
  }
});
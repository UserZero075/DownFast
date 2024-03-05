const $ = selector => document.querySelector(selector)
const socket = io('http://localhost:7569');
let start
let downloadItem;
let downloadProcess;
let ID;
let storedDownloadProcess = localStorage.getItem('downloadProcess');
let startedDownloadProcess = localStorage.getItem('start');

if (storedDownloadProcess) {
  if (startedDownloadProcess === 'false') {
    start = false
    downloadProcess = []
  } else { 
    if (JSON.parse(storedDownloadProcess).length >= 2) {
      localStorage.setItem('start', 'false');
      downloadProcess = []
    } else {
      downloadProcess = JSON.parse(storedDownloadProcess);
    }
  }
} else {
  downloadProcess = [];
}
start = localStorage.getItem('start') === 'false' ? false : true

const generateRandomID = (length) => {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let randomID = '';
  for (let i = 0; i < length; i++) {
    const randomIndex = Math.floor(Math.random() * characters.length);
    randomID += characters.charAt(randomIndex);
  }
  return randomID;
}

const createDownloadItem = (id) => {
  const downloadItem = document.createElement("div");
  downloadItem.className = "download-item";
  downloadItem.id = id

  const downloadInfo = document.createElement("div");
  downloadInfo.className = "download-info";

  const detailsContainer = document.createElement("div");
  detailsContainer.className = "details-container";

  const title = document.createElement("h3");
  title.id = 'title';
  title.className = "title";
  title.textContent = "Procesando...";

  const sizeMetadata = document.createElement("p");
  sizeMetadata.id = 'sizeMetadata'
  sizeMetadata.className = "metadata";
  sizeMetadata.textContent = "Tamaño: procesando...";

  const dateMetadata = document.createElement("p");
  dateMetadata.className = "metadata";
  let fecha = new Date(); 
  let dia = fecha.getDate(); 
  let mes = fecha.getMonth() + 1; 
  let year = fecha.getFullYear();
  let fechaFormateada = dia + '-' + mes + '-' + year;
  dateMetadata.textContent = `Fecha de Descarga: ${fechaFormateada}`;

  detailsContainer.appendChild(title);
  detailsContainer.appendChild(sizeMetadata);
  detailsContainer.appendChild(dateMetadata);
  downloadInfo.appendChild(detailsContainer);

  const progressContainer = document.createElement("div");
  progressContainer.className = "progress-container";

  const progressBar = document.createElement("div");
  progressBar.className = "progress progress-striped active";
  const progressBarInner = document.createElement("div");
  progressBarInner.className = "progress-bar progress-bar-inverse";
  progressBarInner.id = "progressBarInner";
  progressBarInner.setAttribute("role", "progressbar");
  progressBarInner.setAttribute("aria-valuenow", "0");
  progressBarInner.setAttribute("aria-valuemin", "0");
  progressBarInner.setAttribute("aria-valuemax", "100");
  progressBarInner.style.width = "0%";
  progressBar.appendChild(progressBarInner);

  const progressDetails = document.createElement("p");
  progressDetails.id = 'progressDetails';
  progressDetails.className = "progress-details";
  progressDetails.textContent = "Hilos: 0 | 0 MB / 0 MB";

  const cancelButton = document.createElement("button");
  cancelButton.id = 'cancelButton';
  cancelButton.className = "cancel-button";
  cancelButton.style = 'visibility: hidden;'
  cancelButton.textContent = "Cancelar";
  cancelButton.addEventListener("click", function() {
    start = false
    localStorage.setItem('start', 'false');
    downloadProcess = []
    socket.emit('cancel', true)
    downloadItem.remove()
  });

  progressContainer.appendChild(progressBar);
  progressContainer.appendChild(progressDetails);
  progressContainer.appendChild(cancelButton);

  downloadItem.appendChild(downloadInfo);
  downloadItem.appendChild(progressContainer);

  const downloadsSection = document.querySelector(".downloads-section");

  if (downloadsSection) {
    downloadsSection.appendChild(downloadItem);
    downloadProcess.push(downloadItem.id)
    localStorage.setItem('downloadProcess', JSON.stringify(downloadProcess));
    console.log(localStorage)
  } else {
    console.error("No se encontró el elemento .downloads-section en el documento.");
  }
}

document.addEventListener("visibilitychange", function() {
  if (document.visibilityState === 'hidden') {} else {
    socket.connect();
  }
});
let i = 0

socket.on('downloading', (data) => {
  console.log('ds')
  data = JSON.parse(data);
  if (localStorage.getItem('startDownload').length > 10 && i === 0) {
    i++
    createDownloadItem(localStorage.getItem('startDownload'))
    downloadItem = document.getElementById(`${localStorage.getItem('startDownload')}`)
  } else {
    downloadItem = document.getElementById(`${ID}`)
  }
  const cancelButton = downloadItem.querySelector('#cancelButton');
  cancelButton.style = 'visibility: visible;'
  const progressDetails = downloadItem.querySelector('#progressDetails');
  const progressBarInner = downloadItem.querySelector('.progress-bar-inverse');
  const sizeMetadata = downloadItem.querySelector('#sizeMetadata');
  const title = downloadItem.querySelector('#title');

  if (((data.transferred / (1024*1024)).toFixed(2) / Number(data.total.replace(' MB', '')) * 100).toFixed(0) >= 99) {
    start = false
    localStorage.setItem('start', 'false');
    downloadProcess = []
    cancelButton.remove()
    progressBarInner.style.width = `100%`;
    progressBarInner.innerHTML = `100% ${(data.speed / (1024*1024)).toFixed(2)}MB/s Terminado`;
  } else {
    progressBarInner.style.width = `${((data.transferred / (1024*1024)).toFixed(2) / Number(data.total.replace(' MB', '')) * 100).toFixed(0)}%`;
    progressBarInner.innerHTML = `${((data.transferred / (1024*1024)).toFixed(2) / Number(data.total.replace(' MB', '')) * 100).toFixed(1)}% ${(data.speed / (1024*1024)).toFixed(2)}MB/s`;
  }

  title.innerHTML = data.fileName.split('-')[0].length > 25 ? data.fileName.split('-')[0].substring(0, 25) : data.fileName.split('-')[0]
  sizeMetadata.innerHTML = 'Tamaño: ' + data.total;
  if (((data.transferred / (1024*1024)).toFixed(2) / Number(data.total.replace(' MB', '')) * 100).toFixed(0) > 35) {
    progressDetails.innerHTML = `Hilos: ${data.numberThreads} | ${(data.transferred / (1024*1024)).toFixed(2)} MB / ${data.total}`;
  } else {
    progressDetails.innerHTML = `Hilos: ${data.numberThreads} | ${(data.transferred / (1024*1024)).toFixed(2)} MB / ${data.total} | ${((data.transferred / (1024*1024)).toFixed(2) / Number(data.total.replace(' MB', '')) * 100).toFixed(1)}% ${(data.speed / (1024*1024)).toFixed(2)}MB/s`;
  }
});


const reconnect = () => {
  socket.connect();
}

const sendLink = () => {
  const linkInput = document.getElementById('linkElement');
  const link = linkInput.value.trim();
  if (link.trim() !== '' && start === false) {
    i++
    start = true
    localStorage.setItem('start', 'true');
    ID = generateRandomID(50)
    socket.emit('link_download', JSON.stringify({
      link,
      ID
    }));
    linkInput.value = '';
    createDownloadItem(ID)
  }
}


socket.on('downloadFalse', (data) => {
  localStorage.setItem('start', data);
  localStorage.setItem('startDownload', data);
})

socket.on('downloadTrue', (data) => {
  localStorage.setItem('startDownload', data);
})


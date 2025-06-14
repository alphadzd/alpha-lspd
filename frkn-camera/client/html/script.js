let recordInterval;
let startTime;
let camsData = []
let firstLoad = true; 
let currentCam = null;  
let sortBy = "number"; 


window.addEventListener("message", function (e) {
    e = e.data
    switch (e.action) {
    case "openCam":
        return openCam(e);
    case "closeCam":
        return closeCam(e);
    case "updateMousePosition":
        return updateMousePosition(e);
    case "playerDetected":
        return playerDetected(e);
    case "playerNotDetected":
        return playerNotDetected(e);
    case "openCamList":
        camsData = e.camData;
        return openCamList(e);
    case "updateCamDetection":
        return updateCamDetection(e);
    case "updateCam":
        return updateCam(e);
    default:
    return;
    }
});



function playerDetected(e) {
    $('.info-box .name').text(e.player);
    $('.dedected-list').empty();

    $('.info-box .header').text('Suspect Information');

    $('.info-box .img-box').empty();
    $('.info-box .img-box').html(`<img src="../html/images/user-face.png" alt="avatar" class="face">`);
    

    if (e.signal && e.weaponDetected) {
        $('.signal').text('Very Dangerous');
        $('.signal').css('background-color', 'rgba(255, 0, 0, 0.35)');
        $('.signal').css('color', '#FF0000');
    } else if (e.weaponDetected || e.maskDetected) {
        $('.signal').text('Dangerous');
        $('.signal').css('background-color', 'rgba(255, 165, 0, 0.35)');
        $('.signal').css('color', '#FFA500');
    } else {
        $('.signal').text('Safe');
        $('.signal').css('background-color', 'rgba(0, 255, 0, 0.35)');
        $('.signal').css('color', '#00FF00');
    }

    if (e.maskDetected) {
        const item = `
            <div class="dedected-item">
                <div class="dedected-name">Mask detected</div>
                <div class="warning-icon active" style="left: 57%;"> 
                  <svg width="20" height="21" viewBox="0 0 20 21" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M10.0031 1.90265C5.40638 1.90265 3.24451 5.7528 3.24451 10.502C3.24451 15.2512 6.56701 19.1016 10.0031 19.1016C13.4392 19.1016 16.7617 15.2514 16.7617 10.502C16.7617 5.75265 14.6 1.90265 10.0031 1.90265ZM8.98435 12.0536C9.00395 12.0307 9.02786 12.012 9.05472 11.9984C9.08157 11.9848 9.11084 11.9766 9.14086 11.9744C9.17087 11.9721 9.20104 11.9758 9.22963 11.9852C9.25822 11.9946 9.28467 12.0096 9.30748 12.0292C9.78513 12.44 10.2294 12.4401 10.7078 12.0292C10.7539 11.9896 10.8138 11.9699 10.8745 11.9744C10.9351 11.979 10.9914 12.0075 11.0311 12.0536C11.0707 12.0997 11.0904 12.1596 11.0858 12.2203C11.0813 12.2809 11.0528 12.3372 11.0067 12.3769C10.7361 12.6344 10.3809 12.7843 10.0076 12.7987C9.63436 12.7844 9.27914 12.6344 9.00857 12.3769C8.98575 12.3572 8.96702 12.3333 8.95346 12.3064C8.93989 12.2795 8.93175 12.2503 8.9295 12.2202C8.92725 12.1902 8.93094 12.1601 8.94035 12.1315C8.94976 12.1029 8.96471 12.0764 8.98435 12.0536ZM5.21294 10.0953C5.21294 9.30343 6.04373 8.66156 7.06841 8.66156C8.0931 8.66156 8.92373 9.30343 8.92373 10.0953C8.92373 10.8872 8.09373 11.5291 7.06841 11.5291C6.0431 11.5291 5.21294 10.887 5.21294 10.0953ZM12.0781 15.4189C11.8139 15.7011 11.4925 15.9238 11.1355 16.072C10.7784 16.2201 10.3939 16.2905 10.0075 16.2783C9.62105 16.2905 9.23646 16.2202 8.87938 16.072C8.52229 15.9238 8.20091 15.7011 7.93669 15.4189C7.90871 15.3878 7.88755 15.3512 7.87458 15.3115C7.86161 15.2717 7.85713 15.2297 7.86141 15.1881C7.8657 15.1465 7.87866 15.1063 7.89946 15.07C7.92026 15.0337 7.94843 15.0022 7.98216 14.9775C8.53529 14.5691 9.0206 14.1848 9.47763 14.1848C9.61062 14.1786 9.7422 14.2143 9.85373 14.287C9.89943 14.3168 9.95283 14.3327 10.0074 14.3327C10.062 14.3327 10.1154 14.3168 10.1611 14.287C10.2726 14.2143 10.4042 14.1786 10.5372 14.1848C10.9942 14.1848 11.4795 14.5691 12.0326 14.9775C12.0664 15.0022 12.0945 15.0337 12.1153 15.07C12.1361 15.1063 12.1491 15.1465 12.1534 15.1881C12.1577 15.2297 12.1532 15.2717 12.1402 15.3115C12.1272 15.3512 12.1061 15.3878 12.0781 15.4189ZM12.9469 11.5291C11.9222 11.5291 11.0915 10.887 11.0915 10.0953C11.0915 9.30359 11.9222 8.66156 12.9469 8.66156C13.9715 8.66156 14.8023 9.30343 14.8023 10.0953C14.8023 10.8872 13.972 11.5291 12.9473 11.5291H12.9469Z" fill="white" fill-opacity="0.25"/>
                    <path d="M10.6508 15.4096H9.36481C9.29946 15.4096 9.23679 15.3836 9.19058 15.3374C9.14437 15.2912 9.11841 15.2285 9.11841 15.1632C9.11841 15.0978 9.14437 15.0351 9.19058 14.9889C9.23679 14.9427 9.29946 14.9167 9.36481 14.9167H10.6508C10.7161 14.9167 10.7788 14.9427 10.825 14.9889C10.8712 15.0351 10.8972 15.0978 10.8972 15.1632C10.8972 15.2285 10.8712 15.2912 10.825 15.3374C10.7788 15.3836 10.7161 15.4096 10.6508 15.4096Z" fill="white" fill-opacity="0.25"/>
                    <path d="M17.1497 17.0174L17.3469 17.3782C17.3812 17.4408 17.4328 17.4924 17.4955 17.5267L17.8563 17.7241C17.9152 17.7562 17.9645 17.8036 17.9988 17.8614C18.0331 17.9191 18.0512 17.985 18.0512 18.0522C18.0512 18.1194 18.0331 18.1853 17.9988 18.2431C17.9645 18.3008 17.9152 18.3482 17.8563 18.3803L17.4955 18.5777C17.4328 18.612 17.3812 18.6636 17.3469 18.7263L17.1497 19.0871C17.1175 19.146 17.0701 19.1952 17.0124 19.2295C16.9546 19.2638 16.8887 19.2819 16.8216 19.2819C16.7544 19.2819 16.6885 19.2638 16.6308 19.2295C16.573 19.1952 16.5256 19.146 16.4934 19.0871L16.2961 18.7263C16.2618 18.6635 16.2102 18.612 16.1475 18.5777L15.7867 18.3803C15.7278 18.3482 15.6786 18.3008 15.6443 18.243C15.61 18.1853 15.5919 18.1194 15.5919 18.0522C15.5919 17.9851 15.61 17.9192 15.6443 17.8614C15.6786 17.8037 15.7278 17.7562 15.7867 17.7241L16.1475 17.5267C16.2102 17.4925 16.2618 17.4409 16.2961 17.3782L16.4934 17.0174C16.5256 16.9584 16.573 16.9092 16.6308 16.8749C16.6885 16.8407 16.7544 16.8226 16.8216 16.8226C16.8887 16.8226 16.9546 16.8407 17.0124 16.8749C17.0701 16.9092 17.1175 16.9584 17.1497 17.0174Z" fill="white" fill-opacity="0.25"/>
                    <path d="M2.01747 3.38187L2.21481 3.74265C2.24911 3.80534 2.30069 3.85686 2.36341 3.89109L2.72419 4.08843C2.78314 4.12058 2.83234 4.16802 2.86662 4.22576C2.9009 4.2835 2.91899 4.34941 2.91899 4.41656C2.91899 4.4837 2.9009 4.54961 2.86662 4.60735C2.83234 4.66509 2.78314 4.71253 2.72419 4.74468L2.36341 4.94203C2.30069 4.97626 2.24911 5.02778 2.21481 5.09046L2.01747 5.45124C1.98536 5.51024 1.93793 5.55948 1.88019 5.59379C1.82244 5.62811 1.75652 5.64621 1.68935 5.64621C1.62218 5.64621 1.55625 5.62811 1.49851 5.59379C1.44076 5.55948 1.39334 5.51024 1.36122 5.45124L1.1645 5.08999C1.13012 5.02737 1.07857 4.97587 1.01591 4.94156L0.655127 4.74421C0.596176 4.71206 0.546975 4.66462 0.512696 4.60688C0.478417 4.54914 0.460327 4.48324 0.460327 4.41609C0.460327 4.34894 0.478417 4.28303 0.512696 4.22529C0.546975 4.16755 0.596176 4.12011 0.655127 4.08796L1.0156 3.89062C1.07826 3.8563 1.12981 3.8048 1.16419 3.74218L1.36153 3.3814C1.39372 3.32251 1.44117 3.27337 1.4989 3.23915C1.55664 3.20493 1.62253 3.1869 1.68964 3.18695C1.75675 3.187 1.82262 3.20512 1.8803 3.23942C1.93799 3.27372 1.98537 3.32293 2.01747 3.38187Z" fill="white" fill-opacity="0.25"/>
                    <path d="M3.78608 0.981851L3.91499 1.21748C3.93737 1.25845 3.97105 1.29213 4.01202 1.31451L4.24765 1.44341C4.28612 1.46442 4.31822 1.49539 4.34059 1.53309C4.36296 1.57078 4.37476 1.6138 4.37476 1.65763C4.37476 1.70146 4.36296 1.74448 4.34059 1.78218C4.31822 1.81987 4.28612 1.85085 4.24765 1.87185L4.01202 2.00076C3.97105 2.02313 3.93737 2.05681 3.91499 2.09779L3.78608 2.33341C3.76508 2.37188 3.73411 2.40399 3.69641 2.42636C3.65872 2.44872 3.6157 2.46053 3.57186 2.46053C3.52803 2.46053 3.48501 2.44872 3.44732 2.42636C3.40962 2.40399 3.37865 2.37188 3.35765 2.33341L3.22874 2.09779C3.20636 2.05681 3.17268 2.02313 3.13171 2.00076L2.89593 1.87185C2.8575 1.85081 2.82544 1.81983 2.8031 1.78214C2.78077 1.74445 2.76898 1.70144 2.76898 1.65763C2.76898 1.61382 2.78077 1.57082 2.8031 1.53313C2.82544 1.49544 2.8575 1.46445 2.89593 1.44341L3.13171 1.31451C3.17268 1.29213 3.20636 1.25845 3.22874 1.21748L3.35765 0.981851C3.37865 0.94338 3.40962 0.911274 3.44732 0.888907C3.48501 0.86654 3.52803 0.854736 3.57186 0.854736C3.6157 0.854736 3.65872 0.86654 3.69641 0.888907C3.73411 0.911274 3.76508 0.94338 3.78608 0.981851Z" fill="white" fill-opacity="0.25"/>
                  </svg>
                </div>
            </div>`
        $('.dedected-list').append(item);
    }

    if(e.weaponDetected){
        const item = `
            <div class="dedected-item">
                <div class="dedected-name">Weapon detected</div>
                <div class="warning-icon active" style="left: 57%;"> 
                  <svg width="20" height="21" viewBox="0 0 20 21" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M19.3195 0.813821C19.0826 0.598197 18.7135 0.619017 18.487 0.84554L18.3077 1.02488L17.9056 0.622806C17.7562 0.473431 17.513 0.455697 17.3543 0.59515C17.1804 0.747923 17.174 1.01308 17.335 1.17413L17.7467 1.58581L17.0753 2.25726L16.8367 2.0187C16.6044 1.78632 16.2276 1.78632 15.9953 2.0187L11.7506 6.26339C11.5823 6.43171 11.5366 6.67558 11.6121 6.88562L11.1891 7.30863C11.124 7.28468 11.0548 7.27148 10.9841 7.27148C10.8263 7.27148 10.6749 7.33417 10.5634 7.44574L9.89737 8.11175L9.26979 7.48417C8.92589 7.14023 8.38225 7.11257 8.00526 7.4198L5.57776 9.39753C5.37096 9.56601 5.2446 9.81542 5.23104 10.0818C5.21749 10.3482 5.31788 10.6092 5.50647 10.7978L6.35893 11.6502L5.69292 12.3162C5.58135 12.4278 5.51866 12.5792 5.51866 12.7369C5.51866 12.809 5.53233 12.8794 5.5571 12.9455L5.14538 13.3523C4.9353 13.2768 4.69143 13.3225 4.52315 13.4909L0.659713 17.3543C0.423268 17.5907 0.428033 17.9755 0.670299 18.206L2.90905 20.336C3.17108 20.5853 3.59303 20.5451 3.80327 20.2509L6.98448 15.7979C7.14647 15.5616 7.11706 15.2434 6.91444 15.0408L6.59034 14.7167L6.92081 14.3855L7.44397 14.9087L8.43952 17.8746C8.5226 18.1221 8.75362 18.2803 9.00331 18.2803C9.05503 18.2803 9.10756 18.2735 9.15979 18.2594L11.7142 17.5643C11.9077 17.5116 12.0692 17.3709 12.1342 17.1812C12.2265 16.9115 12.117 16.6228 11.8828 16.4792L11.6362 16.328L10.8685 13.5066L11.5631 12.9171C12.6142 13.6625 13.8785 14.0703 15.1785 14.0703C15.3996 14.0703 15.6219 14.0585 15.8442 14.0346C16.0636 14.011 16.2508 13.865 16.3309 13.6594L17.0088 11.919C17.0842 11.7255 17.0532 11.5066 16.927 11.3416C16.8008 11.1766 16.5978 11.0893 16.3912 11.1115C15.3839 11.219 14.3807 11.0187 13.5057 10.5597C13.5098 10.5201 13.513 10.4803 13.5147 10.4403C13.5367 9.90019 13.3301 9.37113 12.9479 8.98886L12.633 8.67402L12.9764 8.33066L13.5654 8.91964C13.6773 9.03156 13.8288 9.0939 13.986 9.0939C13.9984 9.0939 14.0108 9.09351 14.0232 9.09273C14.1935 9.0821 14.3511 8.99878 14.4558 8.86398L18.1681 4.08683C18.3522 3.84995 18.3311 3.51316 18.119 3.30105L17.9166 3.09867L19.3403 1.67503C19.5794 1.43597 19.5724 1.04402 19.3195 0.813821ZM8.86456 12.5802L8.55979 12.885C8.48233 12.9624 8.38085 13.0011 8.27932 13.0011C8.1778 13.0011 8.07628 12.9624 7.99885 12.885C7.84397 12.7301 7.84397 12.4789 7.99889 12.324L8.30366 12.0193C8.45858 11.8644 8.70975 11.8644 8.8646 12.0193C9.01948 12.1742 9.01948 12.4253 8.86456 12.5802ZM7.20034 10.8088L6.53999 10.1485L8.58506 8.4823L9.05596 8.9532L7.20034 10.8088Z" fill="white" fill-opacity="0.25"/>
                  </svg>
                </div>
            </div>`
    $('.dedected-list').append(item);
    }
}

function playerNotDetected(e) {
    $('.info-box .header').text('No Suspect Detected');
    $('.info-box .name').text('');
    $('.dedected-list').empty();
    $('.info-box .img-box').empty();
    $('.signal').text('');
    $('.signal').css('background-color', 'transparent');
}

function sortCamList(camData) {
    return camData.sort((a, b) => {
        if (sortBy === "risk") {
            const riskLevel = (cam) => {
                if (!cam.broken && cam.hasWeapon && cam.hasMask && cam.grouping) return 3;
                if (!cam.broken && (cam.hasWeapon || cam.hasMask || cam.grouping)) return 2; 
                return 1; 
            };

            return riskLevel(b) - riskLevel(a); 
        } else {
            return a.index - b.index;
        }
    });
}


function openCamList(e) {
    currentCam = "camlist"
    $('body , .main-page').css('display', 'flex');
    $('.cam-page').css('display', 'none');

    if (firstLoad) {
        $('.cam-list').empty(); 
        firstLoad = false;
    }

    let camData = camsData.map((cam, index) => {
        const detectedData = e.camDetectionData && e.camDetectionData[index] ? e.camDetectionData[index].detected : [];
        const grouping = e.camDetectionData && e.camDetectionData[index] ? e.camDetectionData[index].grouping : false;
    
        const hasWeapon = detectedData.some(player => player.weaponDetected);
        const hasMask = detectedData.some(player => player.maskDetected);
    
        let weaponClass = "";
        let maskClass = "";
        let groupingClass = "";
        
        const allDetected = hasWeapon && hasMask && grouping;
        
        if (allDetected) {
            weaponClass = "active";
            maskClass = "active";
            groupingClass = "active";
        } else {
            if (hasWeapon) weaponClass = "orange-active";
            if (hasMask) maskClass = "orange-active";
            if (grouping) groupingClass = "orange-active";
        }

        
        
        let camImage = cam.image;
        let warningContent = '';
        let warningText = 'Normal';
        let warningColor = '#8AFF92';
        let warningBg = 'rgba(49, 125, 54, 0.24) !important;';
        let allBg = 'linear-gradient(331deg, rgba(0, 0, 0, 0.00) 8.45%, rgba(82, 255, 93, 0.20) 100%), rgba(255, 255, 255, 0.03) !important;';
        let nameColor = 'white';
        let gpsImg = 'gps-icon-green';
        let indexColor = 'white';
        let codeBg = 'rgba(255, 255, 255, 0.08)';
        let textShadow = '0px 0px 15px rgba(255, 255, 255, 0.83)';

        if (!cam.broken && (hasWeapon || hasMask || grouping)) {
            camImage = cam.image;
            warningContent = '<div class="warning-img"></div>';
            warningText = 'Warning';
            warningColor = 'orange';
            warningBg = 'rgba(255, 165, 0, 0.35) !important;';
            allBg = 'linear-gradient(331deg, rgba(0, 0, 0, 0.00) 8.45%, rgba(255, 149, 0, 0.20) 100%), rgba(255, 255, 255, 0.03) !important;';
            nameColor = 'white';
            gpsImg = 'gps-icon-white';
            indexColor = 'white';
            codeBg = 'rgba(255, 255, 255, 0.08);';
            textShadow = '0px 0px 15px rgba(255, 255, 255, 0.83)';
        }

        if (cam.broken) {
            camImage = "nosignal.png";
            allBg = 'linear-gradient(331deg, rgba(0, 0, 0, 0.00) 8.45%, rgba(207, 207, 207, 0.20) 100%), rgba(255, 255, 255, 0.03) !important';
            warningContent = ``;
            warningText = 'No Signal';
            warningColor = 'rgba(207, 207, 207,0.14)';
            indexColor = 'rgba(255, 255, 255, 0.17)';
            warningBg = 'rgba(255, 255, 255, 0.05) !important;';
            nameColor = 'rgba(255, 255, 255, 0.17)';
            codeBg = 'radial-gradient(94.82% 77.03% at 50% 50%, rgba(255, 255, 255, 0.08) 0%, rgba(153, 153, 153, 0.00) 100%);';
            gpsImg = 'gps-icon-signal';
            maskClass = '';
            weaponClass = '';
            textShadow = '0px 0px 15px rgba(255, 255, 255, 0)';
            groupingClass = '';
        }
    
        if (!cam.broken && (hasWeapon & hasMask & grouping)) {
            camImage = cam.image;
            warningContent = `
                <div class="error-img" style="background: url(../html/images/${camImage}) lightgray 50% / cover no-repeat;">
                    <img src="../html/images/warning.png" alt="">
                    <div class="hr"></div>
                    <div class="text">Warning!</div>
                    <div class="text-2">Warning!</div>
                </div>`;
            warningText = 'High Risk';
            warningColor = '#FF0000';
            warningBg = 'rgba(115, 23, 23, 0.24) !important;';
            allBg = 'linear-gradient(331deg, rgba(0, 0, 0, 0.00) 8.45%, rgba(232, 45, 45, 0.20) 100%), rgba(255, 255, 255, 0.03) !important;';
            nameColor = 'white';
            gpsImg = 'gps-icon-white';
            indexColor = 'white';
            codeBg = 'rgba(255, 255, 255, 0.08);';
            textShadow = '0px 0px 15px rgba(255, 255, 255, 0.83)';
        }
    
        return {
            ...cam,
            index: index + 1,
            id : index + 1,
            hasWeapon,
            hasMask,
            grouping,
            warningContent,
            warningText,
            warningColor,
            warningBg,
            allBg,
            weaponClass,
            nameColor,
            maskClass,
            gpsImg,
            codeBg,
            indexColor,
            groupingClass,
            textShadow,
            camImage,
        };
    });

    camData = sortCamList(camData);

    const existingIds = $('.cam-item').map(function () {
        return $(this).attr('data-id');
    }).get();

    const newIds = camData.map(cam => cam.id.toString());

    existingIds.forEach(id => {
        if (!newIds.includes(id)) {
            $(`.cam-item[data-id="${id}"]`).remove();
        }
    });

    camData.forEach((cam, index) => {
        index = index + 1;
        const formattedIndex = index < 10 
        ? `<span style="color: rgba(255, 255, 255, 0.17);font-family: 'Monument Extended';">0</span>${index}`
        : index;

        // const camImage = cam.broken ? "nosignal.png" : cam.image;
        const existingItem = $(`.cam-item[data-id="${cam.id}"]`);
        if (existingItem.length > 0) {
            existingItem.find('.index').html(formattedIndex);
            existingItem.find('.name').text(cam.name);
            existingItem.find('.street').text(cam.street);
            existingItem.find('.code').text(cam.code);
            existingItem.find('.warning').text(cam.warningText).css({'color': cam.warningColor , 'background': cam.warningBg});
          
            const icons = existingItem.find('.warning-icon');
            icons.eq(0).removeClass("active").addClass(cam.weaponClass);
            icons.eq(1).removeClass("active").addClass(cam.maskClass);
            icons.eq(2).removeClass("active").addClass(cam.groupingClass);

            const imgElement = existingItem.find('.cam-img');
            const realSrc = `../html/images/${cam.camImage}`;
            const tempImg = new Image();
            tempImg.src = realSrc;

            tempImg.onload = () => {
                imgElement.attr('src', realSrc).css({
                    'width': '100%',
                    'height': '60%',
                    'opacity': '1',
                    'transition': 'opacity 0.5s ease-in-out'
                });
            };

            
        } else {

        const item = $(`
            <div class="cam-item"  data-id="${cam.id}">
            ${cam.warningContent}
            <div style="background:${cam.allBg}" class="bg-new"></div>
            <div class="cam-bg"></div> 
            <img style="width:15%;height:15%" src="../html/images/loading.gif" class="cam-img" data-src="../html/images/${cam.camImage}" alt="">
            <div class="gps-icon">
              <img src="../html/images/${cam.gpsImg}.png" alt="">
            </div>
            <div style="color:${cam.indexColor}" class="index"> ${formattedIndex}</div>
            <div style="color:${cam.nameColor}; background:${cam.codeBg} text-shadow:${cam.textShadow} " class="name">${cam.name}</div>
            <div style="color:${cam.indexColor}" class="street">${cam.street}</div>
            <div style="color:${cam.indexColor}; background:${cam.codeBg}" class="code">${cam.code}</div>
            <div class="warning" style="color: ${cam.warningColor};background:${cam.warningBg}">${cam.warningText}</div>
            <div class="warning-icon  ${cam.weaponClass}"">
              <svg width="20" height="21" viewBox="0 0 20 21" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M19.3195 0.813821C19.0826 0.598197 18.7135 0.619017 18.487 0.84554L18.3077 1.02488L17.9056 0.622806C17.7562 0.473431 17.513 0.455697 17.3543 0.59515C17.1804 0.747923 17.174 1.01308 17.335 1.17413L17.7467 1.58581L17.0753 2.25726L16.8367 2.0187C16.6044 1.78632 16.2276 1.78632 15.9953 2.0187L11.7506 6.26339C11.5823 6.43171 11.5366 6.67558 11.6121 6.88562L11.1891 7.30863C11.124 7.28468 11.0548 7.27148 10.9841 7.27148C10.8263 7.27148 10.6749 7.33417 10.5634 7.44574L9.89737 8.11175L9.26979 7.48417C8.92589 7.14023 8.38225 7.11257 8.00526 7.4198L5.57776 9.39753C5.37096 9.56601 5.2446 9.81542 5.23104 10.0818C5.21749 10.3482 5.31788 10.6092 5.50647 10.7978L6.35893 11.6502L5.69292 12.3162C5.58135 12.4278 5.51866 12.5792 5.51866 12.7369C5.51866 12.809 5.53233 12.8794 5.5571 12.9455L5.14538 13.3523C4.9353 13.2768 4.69143 13.3225 4.52315 13.4909L0.659713 17.3543C0.423268 17.5907 0.428033 17.9755 0.670299 18.206L2.90905 20.336C3.17108 20.5853 3.59303 20.5451 3.80327 20.2509L6.98448 15.7979C7.14647 15.5616 7.11706 15.2434 6.91444 15.0408L6.59034 14.7167L6.92081 14.3855L7.44397 14.9087L8.43952 17.8746C8.5226 18.1221 8.75362 18.2803 9.00331 18.2803C9.05503 18.2803 9.10756 18.2735 9.15979 18.2594L11.7142 17.5643C11.9077 17.5116 12.0692 17.3709 12.1342 17.1812C12.2265 16.9115 12.117 16.6228 11.8828 16.4792L11.6362 16.328L10.8685 13.5066L11.5631 12.9171C12.6142 13.6625 13.8785 14.0703 15.1785 14.0703C15.3996 14.0703 15.6219 14.0585 15.8442 14.0346C16.0636 14.011 16.2508 13.865 16.3309 13.6594L17.0088 11.919C17.0842 11.7255 17.0532 11.5066 16.927 11.3416C16.8008 11.1766 16.5978 11.0893 16.3912 11.1115C15.3839 11.219 14.3807 11.0187 13.5057 10.5597C13.5098 10.5201 13.513 10.4803 13.5147 10.4403C13.5367 9.90019 13.3301 9.37113 12.9479 8.98886L12.633 8.67402L12.9764 8.33066L13.5654 8.91964C13.6773 9.03156 13.8288 9.0939 13.986 9.0939C13.9984 9.0939 14.0108 9.09351 14.0232 9.09273C14.1935 9.0821 14.3511 8.99878 14.4558 8.86398L18.1681 4.08683C18.3522 3.84995 18.3311 3.51316 18.119 3.30105L17.9166 3.09867L19.3403 1.67503C19.5794 1.43597 19.5724 1.04402 19.3195 0.813821ZM8.86456 12.5802L8.55979 12.885C8.48233 12.9624 8.38085 13.0011 8.27932 13.0011C8.1778 13.0011 8.07628 12.9624 7.99885 12.885C7.84397 12.7301 7.84397 12.4789 7.99889 12.324L8.30366 12.0193C8.45858 11.8644 8.70975 11.8644 8.8646 12.0193C9.01948 12.1742 9.01948 12.4253 8.86456 12.5802ZM7.20034 10.8088L6.53999 10.1485L8.58506 8.4823L9.05596 8.9532L7.20034 10.8088Z" fill="white" fill-opacity="0.25"/>
              </svg>
            </div>
            <div class="warning-icon  ${cam.maskClass}" style="left: 57%;"> 
              <svg width="20" height="21" viewBox="0 0 20 21" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M10.0031 1.90265C5.40638 1.90265 3.24451 5.7528 3.24451 10.502C3.24451 15.2512 6.56701 19.1016 10.0031 19.1016C13.4392 19.1016 16.7617 15.2514 16.7617 10.502C16.7617 5.75265 14.6 1.90265 10.0031 1.90265ZM8.98435 12.0536C9.00395 12.0307 9.02786 12.012 9.05472 11.9984C9.08157 11.9848 9.11084 11.9766 9.14086 11.9744C9.17087 11.9721 9.20104 11.9758 9.22963 11.9852C9.25822 11.9946 9.28467 12.0096 9.30748 12.0292C9.78513 12.44 10.2294 12.4401 10.7078 12.0292C10.7539 11.9896 10.8138 11.9699 10.8745 11.9744C10.9351 11.979 10.9914 12.0075 11.0311 12.0536C11.0707 12.0997 11.0904 12.1596 11.0858 12.2203C11.0813 12.2809 11.0528 12.3372 11.0067 12.3769C10.7361 12.6344 10.3809 12.7843 10.0076 12.7987C9.63436 12.7844 9.27914 12.6344 9.00857 12.3769C8.98575 12.3572 8.96702 12.3333 8.95346 12.3064C8.93989 12.2795 8.93175 12.2503 8.9295 12.2202C8.92725 12.1902 8.93094 12.1601 8.94035 12.1315C8.94976 12.1029 8.96471 12.0764 8.98435 12.0536ZM5.21294 10.0953C5.21294 9.30343 6.04373 8.66156 7.06841 8.66156C8.0931 8.66156 8.92373 9.30343 8.92373 10.0953C8.92373 10.8872 8.09373 11.5291 7.06841 11.5291C6.0431 11.5291 5.21294 10.887 5.21294 10.0953ZM12.0781 15.4189C11.8139 15.7011 11.4925 15.9238 11.1355 16.072C10.7784 16.2201 10.3939 16.2905 10.0075 16.2783C9.62105 16.2905 9.23646 16.2202 8.87938 16.072C8.52229 15.9238 8.20091 15.7011 7.93669 15.4189C7.90871 15.3878 7.88755 15.3512 7.87458 15.3115C7.86161 15.2717 7.85713 15.2297 7.86141 15.1881C7.8657 15.1465 7.87866 15.1063 7.89946 15.07C7.92026 15.0337 7.94843 15.0022 7.98216 14.9775C8.53529 14.5691 9.0206 14.1848 9.47763 14.1848C9.61062 14.1786 9.7422 14.2143 9.85373 14.287C9.89943 14.3168 9.95283 14.3327 10.0074 14.3327C10.062 14.3327 10.1154 14.3168 10.1611 14.287C10.2726 14.2143 10.4042 14.1786 10.5372 14.1848C10.9942 14.1848 11.4795 14.5691 12.0326 14.9775C12.0664 15.0022 12.0945 15.0337 12.1153 15.07C12.1361 15.1063 12.1491 15.1465 12.1534 15.1881C12.1577 15.2297 12.1532 15.2717 12.1402 15.3115C12.1272 15.3512 12.1061 15.3878 12.0781 15.4189ZM12.9469 11.5291C11.9222 11.5291 11.0915 10.887 11.0915 10.0953C11.0915 9.30359 11.9222 8.66156 12.9469 8.66156C13.9715 8.66156 14.8023 9.30343 14.8023 10.0953C14.8023 10.8872 13.972 11.5291 12.9473 11.5291H12.9469Z" fill="white" fill-opacity="0.25"/>
                <path d="M10.6508 15.4096H9.36481C9.29946 15.4096 9.23679 15.3836 9.19058 15.3374C9.14437 15.2912 9.11841 15.2285 9.11841 15.1632C9.11841 15.0978 9.14437 15.0351 9.19058 14.9889C9.23679 14.9427 9.29946 14.9167 9.36481 14.9167H10.6508C10.7161 14.9167 10.7788 14.9427 10.825 14.9889C10.8712 15.0351 10.8972 15.0978 10.8972 15.1632C10.8972 15.2285 10.8712 15.2912 10.825 15.3374C10.7788 15.3836 10.7161 15.4096 10.6508 15.4096Z" fill="white" fill-opacity="0.25"/>
                <path d="M17.1497 17.0174L17.3469 17.3782C17.3812 17.4408 17.4328 17.4924 17.4955 17.5267L17.8563 17.7241C17.9152 17.7562 17.9645 17.8036 17.9988 17.8614C18.0331 17.9191 18.0512 17.985 18.0512 18.0522C18.0512 18.1194 18.0331 18.1853 17.9988 18.2431C17.9645 18.3008 17.9152 18.3482 17.8563 18.3803L17.4955 18.5777C17.4328 18.612 17.3812 18.6636 17.3469 18.7263L17.1497 19.0871C17.1175 19.146 17.0701 19.1952 17.0124 19.2295C16.9546 19.2638 16.8887 19.2819 16.8216 19.2819C16.7544 19.2819 16.6885 19.2638 16.6308 19.2295C16.573 19.1952 16.5256 19.146 16.4934 19.0871L16.2961 18.7263C16.2618 18.6635 16.2102 18.612 16.1475 18.5777L15.7867 18.3803C15.7278 18.3482 15.6786 18.3008 15.6443 18.243C15.61 18.1853 15.5919 18.1194 15.5919 18.0522C15.5919 17.9851 15.61 17.9192 15.6443 17.8614C15.6786 17.8037 15.7278 17.7562 15.7867 17.7241L16.1475 17.5267C16.2102 17.4925 16.2618 17.4409 16.2961 17.3782L16.4934 17.0174C16.5256 16.9584 16.573 16.9092 16.6308 16.8749C16.6885 16.8407 16.7544 16.8226 16.8216 16.8226C16.8887 16.8226 16.9546 16.8407 17.0124 16.8749C17.0701 16.9092 17.1175 16.9584 17.1497 17.0174Z" fill="white" fill-opacity="0.25"/>
                <path d="M2.01747 3.38187L2.21481 3.74265C2.24911 3.80534 2.30069 3.85686 2.36341 3.89109L2.72419 4.08843C2.78314 4.12058 2.83234 4.16802 2.86662 4.22576C2.9009 4.2835 2.91899 4.34941 2.91899 4.41656C2.91899 4.4837 2.9009 4.54961 2.86662 4.60735C2.83234 4.66509 2.78314 4.71253 2.72419 4.74468L2.36341 4.94203C2.30069 4.97626 2.24911 5.02778 2.21481 5.09046L2.01747 5.45124C1.98536 5.51024 1.93793 5.55948 1.88019 5.59379C1.82244 5.62811 1.75652 5.64621 1.68935 5.64621C1.62218 5.64621 1.55625 5.62811 1.49851 5.59379C1.44076 5.55948 1.39334 5.51024 1.36122 5.45124L1.1645 5.08999C1.13012 5.02737 1.07857 4.97587 1.01591 4.94156L0.655127 4.74421C0.596176 4.71206 0.546975 4.66462 0.512696 4.60688C0.478417 4.54914 0.460327 4.48324 0.460327 4.41609C0.460327 4.34894 0.478417 4.28303 0.512696 4.22529C0.546975 4.16755 0.596176 4.12011 0.655127 4.08796L1.0156 3.89062C1.07826 3.8563 1.12981 3.8048 1.16419 3.74218L1.36153 3.3814C1.39372 3.32251 1.44117 3.27337 1.4989 3.23915C1.55664 3.20493 1.62253 3.1869 1.68964 3.18695C1.75675 3.187 1.82262 3.20512 1.8803 3.23942C1.93799 3.27372 1.98537 3.32293 2.01747 3.38187Z" fill="white" fill-opacity="0.25"/>
                <path d="M3.78608 0.981851L3.91499 1.21748C3.93737 1.25845 3.97105 1.29213 4.01202 1.31451L4.24765 1.44341C4.28612 1.46442 4.31822 1.49539 4.34059 1.53309C4.36296 1.57078 4.37476 1.6138 4.37476 1.65763C4.37476 1.70146 4.36296 1.74448 4.34059 1.78218C4.31822 1.81987 4.28612 1.85085 4.24765 1.87185L4.01202 2.00076C3.97105 2.02313 3.93737 2.05681 3.91499 2.09779L3.78608 2.33341C3.76508 2.37188 3.73411 2.40399 3.69641 2.42636C3.65872 2.44872 3.6157 2.46053 3.57186 2.46053C3.52803 2.46053 3.48501 2.44872 3.44732 2.42636C3.40962 2.40399 3.37865 2.37188 3.35765 2.33341L3.22874 2.09779C3.20636 2.05681 3.17268 2.02313 3.13171 2.00076L2.89593 1.87185C2.8575 1.85081 2.82544 1.81983 2.8031 1.78214C2.78077 1.74445 2.76898 1.70144 2.76898 1.65763C2.76898 1.61382 2.78077 1.57082 2.8031 1.53313C2.82544 1.49544 2.8575 1.46445 2.89593 1.44341L3.13171 1.31451C3.17268 1.29213 3.20636 1.25845 3.22874 1.21748L3.35765 0.981851C3.37865 0.94338 3.40962 0.911274 3.44732 0.888907C3.48501 0.86654 3.52803 0.854736 3.57186 0.854736C3.6157 0.854736 3.65872 0.86654 3.69641 0.888907C3.73411 0.911274 3.76508 0.94338 3.78608 0.981851Z" fill="white" fill-opacity="0.25"/>
              </svg>
            </div>
            <div class="warning-icon ${cam.groupingClass}" style="left: 77.5%;">
              <svg width="20" height="21" viewBox="0 0 20 21" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M10.1137 8.39132C10.4438 8.39132 10.7584 8.46032 11.0444 8.58445C11.0658 8.11776 11.2267 7.68619 11.4848 7.32893C11.3031 7.29096 11.1157 7.27075 10.9238 7.27075H9.10561C8.91412 7.27075 8.72671 7.29076 8.54645 7.32832C8.82144 7.70988 8.98578 8.17554 8.98843 8.67978C9.32262 8.49605 9.70601 8.39132 10.1137 8.39132Z" fill="white" fill-opacity="0.25"/>
                <path d="M10.0143 7.12459C11.1977 7.12459 12.157 6.16525 12.157 4.98185C12.157 3.79845 11.1977 2.83911 10.0143 2.83911C8.83086 2.83911 7.87152 3.79845 7.87152 4.98185C7.87152 6.16525 8.83086 7.12459 10.0143 7.12459Z" fill="white" fill-opacity="0.25"/>
                <path d="M13.3797 10.7809C14.4702 10.7809 15.3538 9.89691 15.3538 8.80676C15.3538 7.7162 14.4702 6.83264 13.3797 6.83264C12.2993 6.83264 11.4233 7.70048 11.407 8.77695C12.0294 9.16728 12.4659 9.8275 12.5455 10.5939C12.7991 10.7127 13.081 10.7809 13.3797 10.7809Z" fill="white" fill-opacity="0.25"/>
                <path d="M6.64931 6.83246C5.55854 6.83246 4.67499 7.71622 4.67499 8.80657C4.67499 9.89693 5.55854 10.7805 6.64931 10.7805C7.03555 10.7805 7.39465 10.6676 7.69924 10.4759C7.79621 9.84487 8.13449 9.29306 8.6177 8.91742C8.61975 8.88047 8.62322 8.84393 8.62322 8.80657C8.62322 7.71622 7.73925 6.83246 6.64931 6.83246Z" fill="white" fill-opacity="0.25"/>
                <path d="M14.6619 6.79042C15.2844 7.18075 15.7208 7.84096 15.8003 8.60754C16.0536 8.72615 16.3357 8.79454 16.6344 8.79454C17.725 8.79454 18.6085 7.91078 18.6085 6.82043C18.6085 5.73007 17.725 4.84631 16.6344 4.84631C15.5543 4.84611 14.6783 5.71415 14.6619 6.79042Z" fill="white" fill-opacity="0.25"/>
                <path d="M10.1137 12.8191C11.2041 12.8191 12.088 11.9352 12.088 10.8448C12.088 9.75442 11.2041 8.87048 10.1137 8.87048C9.02334 8.87048 8.1394 9.75442 8.1394 10.8448C8.1394 11.9352 9.02334 12.8191 10.1137 12.8191Z" fill="white" fill-opacity="0.25"/>
                <path d="M14.2175 10.9154H12.5549C12.5367 11.5805 12.253 12.1795 11.8038 12.61C13.0426 12.9787 13.9492 14.1277 13.9492 15.4849V16.1161C15.5906 16.0555 16.5366 15.5908 16.5989 15.559L16.7307 15.492H16.7444V13.4432C16.7448 12.0492 15.611 10.9154 14.2175 10.9154Z" fill="white" fill-opacity="0.25"/>
                <path d="M17.4721 8.92908H15.8099C15.7919 9.59419 15.5079 10.1932 15.059 10.6237C16.2978 10.9924 17.2042 12.1411 17.2042 13.4983V14.1296C18.8454 14.0691 19.7916 13.6045 19.8539 13.5724L19.9857 13.5057H19.9998V11.4568C19.9998 10.0631 18.866 8.92908 17.4721 8.92908Z" fill="white" fill-opacity="0.25"/>
                <path d="M8.42237 12.6099C7.97549 12.1813 7.69254 11.5856 7.67172 10.9248C7.61027 10.9203 7.54923 10.9152 7.48635 10.9152H5.81172C4.4178 10.9152 3.28375 12.0493 3.28375 13.4432V15.4922L3.28886 15.5239L3.42992 15.5684C4.49701 15.9017 5.44956 16.0549 6.27657 16.1034V15.4847C6.27698 14.1277 7.18319 12.9788 8.42237 12.6099Z" fill="white" fill-opacity="0.25"/>
                <path d="M10.9511 12.9536H9.27589C7.88197 12.9536 6.74792 14.0881 6.74792 15.4814V17.5304L6.75323 17.5625L6.89409 17.6066C8.22433 18.022 9.38001 18.1608 10.3309 18.1608C12.1889 18.1608 13.2656 17.6311 13.3321 17.5974L13.464 17.5304H13.4779V15.4814C13.4785 14.0877 12.3446 12.9536 10.9511 12.9536Z" fill="white" fill-opacity="0.25"/>
                <path d="M3.36561 8.85743C3.66428 8.85743 3.94621 8.78904 4.19976 8.67043C4.27938 7.90385 4.71565 7.24343 5.3381 6.8531C5.32176 5.77704 4.44576 4.909 3.36561 4.909C2.27485 4.909 1.3913 5.79275 1.3913 6.88331C1.3913 7.97367 2.27485 8.85743 3.36561 8.85743Z" fill="white" fill-opacity="0.25"/>
                <path d="M4.9408 10.6868C4.49208 10.2563 4.20811 9.65708 4.19014 8.99176H2.52776C1.13384 8.99196 0 10.126 0 11.5197V13.5688H0.0140862L0.145966 13.6355C0.208435 13.667 1.15425 14.1322 2.79561 14.1924V13.5612C2.79561 12.2042 3.70182 11.0553 4.9408 10.6868Z" fill="white" fill-opacity="0.25"/>
                <path d="M5.67451 6.63731C5.91132 6.54136 6.27267 6.42357 6.61768 6.42357C7.01924 6.42357 7.41202 6.52687 7.76234 6.72346C7.84032 6.64691 7.91177 6.56361 7.97669 6.4744C7.64393 6.03732 7.46224 5.50164 7.46224 4.95064C7.46224 4.5795 7.54512 4.21121 7.70313 3.87662C7.34342 3.55161 6.8845 3.37421 6.39679 3.37421C5.50915 3.37421 4.73645 3.97501 4.51025 4.82121C5.17333 5.20705 5.60531 5.88156 5.67451 6.63731Z" fill="white" fill-opacity="0.25"/>
                <path d="M12.0686 6.3627C12.1372 6.47171 12.2174 6.5744 12.3085 6.66994C12.6327 6.50825 12.9891 6.42333 13.348 6.42333C13.701 6.42333 14.0392 6.51356 14.261 6.5891C14.3304 5.76985 14.8258 5.04676 15.5675 4.68031C15.2956 3.90353 14.5594 3.37335 13.7259 3.37335C13.1869 3.37335 12.6766 3.59465 12.3081 3.98416C12.4375 4.29284 12.503 4.61723 12.503 4.94979C12.5028 5.45914 12.353 5.9446 12.0686 6.3627Z" fill="white" fill-opacity="0.25"/>
              </svg>
            </div>  
          </div>
        `);

        if (cam.warningContent.includes('error-img')) {
            item.find('.error-img').css({
                'background': `url(../html/images/${cam.camImage}) lightgray 50% / cover no-repeat`
            });
        }

        const imgElement = item.find('.cam-img');
        const realSrc = `../html/images/${cam.camImage}`;
        const tempImg = new Image();
        tempImg.src = realSrc;

        tempImg.onload = () => {
            imgElement.attr('src', realSrc).css({
                'width': '100%',
                'height': '60%',
                'opacity': '1',
                'transition': 'opacity 0.5s ease-in-out'
            });
        };

        $('.cam-list').append(item);

        }
    });
}

$(".search-input").on("input", function () {
    let searchText = $(this).val().toLowerCase(); 
    
    $(".cam-item").each(function () {
        let camName = $(this).find(".name").text().toLowerCase(); 
        
        if (camName.includes(searchText)) {
            $(this).show(); 
        } else {
            $(this).hide();
        }
    });
});


$(document).on('click', '.cam-item', function (e) {

    id = $(this).attr('data-id');
    $('body , .main-page').css('display', 'none');
    $('.cam-page').css('display', 'flex');
    $.post('https://frkn-camera/openCam', JSON.stringify({
        id: id
    }));
})

$(document).on('click', '.filter-box', function (e) {
    $(".filter-box").removeClass("box-active");
    $(this).addClass("box-active");

    if ($(this).text().includes("Number")) {
        sortBy = "number";
    } else {
        sortBy = "risk";
    }

    $('.cam-list').empty();
    $('.loading').css('display', 'flex');
    $('.cam-list').css('display', 'none');

    setTimeout(() => {
        $('.loading').css('display', 'none');
        $('.cam-list').css('display', 'flex');

        $('.cam-list').animate({ scrollTop: 0 }, 600, "swing");

        setTimeout(() => {
            openCamList(camsData);
        }, 0);
    }, 1000);
});





function updateCam(e){
    $('.loc-main').text(e.camData.name);
    $('.loc-alt').text(e.camData.street);
}

function openCam(e) {  
    currentCam = "cam"; 
    startRecordingTime();
    renderCoords();
    setInterval(updateDateTime, 1000);
    $('body , .cam-page').css('display', 'flex');
    $('.main-page').css('display', 'none');

    $('.loc-main').text(e.camData.name);
    $('.loc-alt').text(e.camData.street);
}

function startRecordingTime() {
    startTime = Date.now();
    clearInterval(recordInterval);

    recordInterval = setInterval(() => {
        const elapsedTime = Date.now() - startTime;
        const hours = Math.floor(elapsedTime / (1000 * 60 * 60)).toString().padStart(2, '0');
        const minutes = Math.floor((elapsedTime / (1000 * 60)) % 60).toString().padStart(2, '0');
        const seconds = Math.floor((elapsedTime / 1000) % 60).toString().padStart(2, '0');
        $('.record2-box').text(`${hours}:${minutes}:${seconds}`);
    }, 1000);
}

const sensitivity = 800; 
const scrollSpeed = 5; 
function updateMousePosition(e){
    const mouseX = e.mouseX;
    if (mouseX < 0) {
        coordsList.scrollLeft(coordsList.scrollLeft() - scrollSpeed);
    } else if (mouseX > 0) {
        coordsList.scrollLeft(coordsList.scrollLeft() + scrollSpeed);
    }
}

function animateLine(index) {
    if (index >= $('.sound-line').length) {
        setTimeout(() => {
            $('.sound-line').fadeTo(300, 0, function () {
                animateLine(0);
            });
        }, 1000);
        return;
    }
    $('.sound-line').eq(index).fadeTo(300, 1, function () {
        animateLine(index + 1);
    });
}
animateLine(0);

$(document).on('click', '.filter-box', function (e) {
    $('.filter-box').removeClass('box-active');
    $(this).addClass('box-active');
})

$(document).on('click', '.close-icon , .alt-icon', function (e) {
    closeCam();
    $.post('https://frkn-camera/closeNui', JSON.stringify({}));
})

$(document).on('click', '.mode-list .mode', function (e) {
    $('.mode-list .mode').removeClass('active');
    $(this).addClass('active');
    $.post('https://frkn-camera/changeCamMode', JSON.stringify({
        mode: $(this).text()
    }));
})

document.addEventListener('keydown', function (e) {
    if (e.key=="Control") {
        if (currentCam=="cam") {
            $.post('https://frkn-camera/closeFocus', JSON.stringify({}));
        }
    }else if(e.key=="Escape"){
        $.post('https://frkn-camera/closeNui', JSON.stringify({}));
        $('body , .cam-page , .main-page').css('display', 'none');
    }
});


$(document).ready(function () {
    let opacity = 0;
    let increasing = true;

    setInterval(function () {
        if (increasing) {
            opacity += 0.05;
            if (opacity >= 1) increasing = false;
        } else {
            opacity -= 0.05;
            if (opacity <= 0.3) increasing = true;
        }

        $('.record-box').css('box-shadow', `0px 0px 0px 5px rgba(153, 0, 0, ${opacity})`);
    }, 100);
});

function updateDateTime() {
    const now = new Date();
    const date = now.toLocaleDateString('en-GB'); 
    const time = now.toLocaleTimeString('en-GB'); 

    $('.date-box').text(date);
    $('.time-box').text(time);
}

function closeCam(){
    firstLoad = true;
    clearInterval(recordInterval);
    $('.record2-box').text('00:00:00');
    $('body , .cam-page , .main-page').css('display', 'none');
}

const coordsList = $('.coords-list');
function renderCoords() {
    coordsList.empty();
    for (let i = 200; i <= 400; i++) {
        const displayNumber = i === 0 ? 'N' : i;
        if (displayNumber=='N') {
            style = 'color: white;';
        }else{
            style = '';
        }
        const item = `
            <div class="coords-item">
                <div class="line-1"></div>
                <div class="line-2"></div>
                <div class="line-3"></div>
                <div style="${style}" class="number">${displayNumber}</div>
            </div>`;
        coordsList.append(item);
    }
}


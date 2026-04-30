const SHEET_NAME = 'logs';
const TIMEZONE = 'Asia/Tokyo';

function doPost(e) {
  try {
    const sheet = SpreadsheetApp
      .getActiveSpreadsheet()
      .getSheetByName(SHEET_NAME);

    if (!sheet) {
      throw new Error(`${SHEET_NAME} シートが見つかりません`);
    }

    if (!e || !e.postData || !e.postData.contents) {
      throw new Error('POSTデータがありません');
    }

    const data = JSON.parse(e.postData.contents);

    const receivedDate = parseReceivedAt(data.received_at);

    const receivedAt = Utilities.formatDate(
      receivedDate,
      TIMEZONE,
      'yyyy/MM/dd HH:mm:ss'
    );

    const workDate = Utilities.formatDate(
      receivedDate,
      TIMEZONE,
      'yyyy/MM/dd'
    );

    const intervalMs = Number(data.interval_ms || 0);
    const intervalMin = intervalMs
      ? Math.round(intervalMs / 1000 / 60)
      : '';

    const id = sheet.getLastRow();

    const row = [
      id,
      data.device_id || '',
      data.user_name || '',
      data.phone_number || '',
      data.press_count || '',
      data.interval_ms || '',
      intervalMin,
      receivedAt,
      workDate,
      data.source || 'atom',
      data.memo || ''
    ];

    sheet.appendRow(row);

    return jsonResponse({
      status: 'success',
      saved_count: 1,
      received_at: receivedAt,
      work_date: workDate
    });

  } catch (error) {
    return jsonResponse({
      status: 'error',
      message: error.message
    });
  }
}

function doGet(e) {
  return jsonResponse({
    status: 'ok',
    message: 'Karugamo GAS API is running'
  });
}

function parseReceivedAt(value) {
  if (!value) {
    return new Date();
  }

  const date = new Date(value);

  if (isNaN(date.getTime())) {
    return new Date();
  }

  return date;
}

function jsonResponse(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
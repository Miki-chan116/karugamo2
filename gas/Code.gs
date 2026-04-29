const SHEET_NAME = 'logs';

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

    const now = new Date();

    const receivedAt = Utilities.formatDate(
      now,
      'Asia/Tokyo',
      'yyyy/MM/dd HH:mm:ss'
    );

    const workDate = Utilities.formatDate(
      now,
      'Asia/Tokyo',
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
      received_at: receivedAt
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

function jsonResponse(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
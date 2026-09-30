import { useEffect, useState } from 'react';
import { getPlatforms } from '../api/client';
import { isApiError } from '../api/types';
import type { Platform } from '../api/types';

interface Props {
  initialPlatform: string;
  initialRoomId: string;
  onEnterRoom: (platform: string, roomId: string) => void;
}

/**
 * Home: platform selector + roomId input -> room view.
 * Deep link support via ?platform=bilibili&roomId=123 is handled by App.
 */
export default function HomePage({ initialPlatform, initialRoomId, onEnterRoom }: Props) {
  const [platforms, setPlatforms] = useState<Platform[]>([]);
  const [platform, setPlatform] = useState(initialPlatform || 'bilibili');
  const [roomId, setRoomId] = useState(initialRoomId);
  const [loadError, setLoadError] = useState<string | null>(null);

  useEffect(() => {
    let disposed = false;
    getPlatforms()
      .then((res) => {
        if (disposed) return;
        const list = res.platforms ?? [];
        setPlatforms(list);
        setLoadError(null);
        if (list.length > 0 && !list.some((p) => p.id === platform)) {
          setPlatform(list[0].id);
        }
      })
      .catch((err: unknown) => {
        if (disposed) return;
        if (isApiError(err) && err.code === 'NETWORK') {
          setLoadError('无法连接解析服务,请确认解析服务已启动 (127.0.0.1:8787)');
        } else {
          setLoadError('平台列表获取失败,请稍后重试');
        }
      });
    return () => {
      disposed = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const submit = () => {
    const id = roomId.trim();
    if (id.length === 0) return;
    onEnterRoom(platform, id);
  };

  return (
    <div className="home">
      <section className="home-hero">
        <h1>Pure Live</h1>
        <p className="home-sub">输入直播间号,观看 B 站 / 抖音直播</p>
        <form
          className="home-form"
          onSubmit={(e) => {
            e.preventDefault();
            submit();
          }}
        >
          <label className="field">
            <span>平台</span>
            <select
              value={platform}
              onChange={(e) => setPlatform(e.target.value)}
              disabled={platforms.length === 0}
            >
              {platforms.length === 0 && <option value={platform}>{platform || '加载中…'}</option>}
              {platforms.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>房间号</span>
            <input
              value={roomId}
              onChange={(e) => setRoomId(e.target.value)}
              placeholder="例如 21452505"
              inputMode="numeric"
              autoFocus
            />
          </label>
          <button type="submit" className="btn-primary" disabled={roomId.trim().length === 0}>
            进入直播间
          </button>
        </form>
        {loadError && <p className="banner banner-error">{loadError}</p>}
        {platforms.length > 0 && (
          <p className="home-capabilities">
            已支持:{platforms.map((p) => p.name).join('、')}
          </p>
        )}
      </section>
    </div>
  );
}

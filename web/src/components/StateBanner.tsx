/**
 * 列表页统一的加载/空态/错误提示:
 * 加载与空态为居中灰字,错误为红色 banner,传入 onRetry 时附「重试」按钮(重新发起请求)。
 */
export default function StateBanner({
  kind,
  text,
  onRetry,
}: {
  kind: 'error' | 'empty' | 'loading';
  text: string;
  onRetry?: () => void;
}) {
  if (kind === 'error') {
    return (
      <div className="banner banner-error">
        {text}
        {onRetry && (
          <button type="button" className="btn-small" onClick={onRetry}>
            重试
          </button>
        )}
      </div>
    );
  }
  return <p className="state-banner">{text}</p>;
}
